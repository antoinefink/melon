class Blockchain
  # Peers is an array in the form of ["IP:PORT", "IP2:PORT2"] of other nodes.
  attr_accessor :peers

  # To prevent slowing down the application to much, we limit the maximum
  # number of peers we connect to.
  MAX_NUMBER_OF_PEERS = 50

  DIFFICULTY_LEVEL = 5

  def initialize
    @peers = ENV["MLN_PEERS"].to_s.split(",")
  end

  def last_block
    find_block_by_height(last_block_height)
  end

  def save_block(block)
    $db.connection.execute(
      """INSERT INTO blocks
           (height, previous_block_header_hash, block_header_hash, nonce, time, merkle_root, transactions)
         VALUES (?, ?, ?, ?, ?, ?, ?)""",
      [
        block.height,
        block.previous_block_header_hash,
        block.block_header_hash,
        block.nonce,
        block.time.utc.to_s,
        block.merkle_root,
        block.transactions.to_json,
      ]
    )

    block.transactions.each { |tx| record_wallet_transfer(block, tx) }
  end

  def last_block_height
    $db.connection.execute("""
      SELECT height
      FROM blocks
      ORDER BY height DESC
      LIMIT 1
    """).first&.first
  end

  def find_block_by_height(height)
    block = $db.connection.execute("""
      SELECT
        height, previous_block_header_hash, block_header_hash, nonce, time, transactions
      FROM blocks
      WHERE height = ?
      LIMIT 1
    """, height).first

    # Not finding a block means we're mining the first one!
    return if block.nil?

    Block.new(
      self,

      height: block[0],
      previous_block_header_hash: block[1],
      block_header_hash: block[2],
      nonce: block[3],
      time: Time.parse(block[4]),
      transactions: block[5] && JSON.parse(block[5]),
    )
  end

  # Connects to all known peers and requests their highest block. If a block is
  # found, we'll do the necessary validations and then alter our local
  # blockchain.
  def find_higher_blocks_on_the_network
    $logger.info("Looking for higher blocks on the network")

    Array(@peers).each do |peer|
      peer_response = JSON.parse(HTTParty.get("http://#{peer}/blocks/last").body)

      return if peer_response.nil?

      block = Block.initialize_from_json(self, peer_response)

      if block.height > last_block_height.to_i
        $logger.info("Found an higher block: #{block.height} (from #{last_block_height.to_i})")
        validate_and_switch_to_fork(peer, block.height)
      end
    end
  end

  # We fetch all the blocks of the fork until we reach a common point.
  # The blocks are then gradually validated and applied while we revert at the
  # same time the blocks we had created.
  def validate_and_switch_to_fork(peer, target_height)
    new_blocks = []

    height = target_height

    loop do
      new_blocks << Block.initialize_from_json(self, JSON.parse(HTTParty.get("http://#{peer}/blocks/#{height}").body))

      # Once we reach the genesis block or a common point, we can stop fetching
      # blocks.
      break if new_blocks.last.height == 0 ||
          new_blocks.last.previous_block_header_hash == find_block_by_height(height)&.previous_block_header_hash

      height += -1
    end

    # We now reverse our local blockchain before we start applying the fork.
    reverse_blocks_and_transactions_until(new_blocks.last.height - 1)

    new_blocks.reverse.each do |block|
      validate_and_apply_block(block)
    end
  end

  # Validates the block by performing verifications in order:
  # 2. Height and previous block hash
  # 3. Time: Can't be before the previous block.
  # 4. Transactions: Wallets should only spend fund they own. Signatures and
  #    IDs should be valid.
  # 5. There should be exactly one mining reward transaction.
  # 6. Merkle tree root: Should be valid.
  # 7. Block hash: Is it valid and is the level of difficulty what's expected.
  def validate(new_block)
    previous_block = find_block_by_height(new_block.height - 1)

    # 1. Height.
    if previous_block&.height.to_i + 1 != new_block.height.to_i
      raise "Height isn't valid"
    end

    if previous_block.nil? == false
      # 2. Previous block hash
      if previous_block.block_header_hash != new_block.previous_block_header_hash
        raise "Previous block header hash is wrong"
      end

      # 2. Time: Can't be before the previous block.
      if previous_block.time > new_block.time
        raise "New block can't have been created before the previous one"
      end
    end

    # 3. Transactions: Wallets should only spend fund they own.
    new_block.transactions.each do |transaction|
      if WalletTransfer.find(transaction["id"]).nil? == false
        raise "A transaction with the same ID already exists on the blockchain"
      end

      case transaction["message"]["type"]
      when "funds_transfer"
        if valid_cryptography?(transaction) == false
          raise "Cryptography of the transaction is invalid"
        end

        # The amount + fee needs to be available to the wallet.
        if address_has_enough_funds?(transaction["message"]) == false
          raise "From address doesn't have enough funds"
        end

      when "mining_reward"
        fees = new_block.transactions.reject { |t| t["message"]["type"] == "mining_reward" }
          .map { |t| BigDecimal(t["message"]["fee"]) }
          .reduce(&:+) || BigDecimal(0)

        mining_reward = BigDecimal(transaction["message"]["amount"])
        if mining_reward != fees + 1
          raise "Mining reward amount is invalid (#{mining_reward.to_s("F")})"
        end
      end
    end

    # 4. There should be exactly one mining reward transaction.
    mining_rewards = new_block.transactions.reject { |t| t["message"]["type"] != "mining_reward" }
    if mining_rewards.size != 1
      raise "Unexpected amount of mining rewards"
    end

    # 5. Merkle tree root: Should be valid.
    merkle_root = MerkleTree.new(*new_block.transactions.map(&:to_json).sort { |a, b| a["id"] <=> b["id"] }).root.value
    if new_block.merkle_root != merkle_root
      raise "Merkle root is invalid"
    end

    # 6. Block hash: Is it valid and is the level of difficulty what's expected.
    if new_block.compute_block_header_hash != new_block.block_header_hash
      raise "Block header hash is invalid"
    end

    if new_block.block_header_hash[0, DIFFICULTY_LEVEL] != "0" * DIFFICULTY_LEVEL
      raise "Block doesn't match expected difficulty level"
    end
  end

  private

  # We record the changes of wallet balances using the transaction messages.
  # Transactions can contain anything as long as they include a fee for the
  # miner and are signed by a sender with enough funds.
  #
  # The originating address is hashed to standardize the data.
  #
  # We are going to record:
  # 1. The coin reward to the miner for having mined the block (the coinbase).
  # 2. If available, the transfer of fees to the miner as defined in the transactions.
  # 3. If available, the transfer of funds from the sender to the recipient.
  def record_wallet_transfer(block, transaction)
    WalletTransfer.new(
      id: transaction["id"],
      from_address: transaction["message"]["from"] && Digest::SHA256.hexdigest(transaction["message"]["from"]),
      destination_address: transaction["message"]["destination"],
      amount: transaction["message"]["amount"],
      fee: transaction["message"]["fee"],
      block_height: block.height,
    ).insert
  end

  # All transactions and blocks with an height STRICTLY higher than the one
  # provided are deleted.
  def reverse_blocks_and_transactions_until(height)
    $db.connection.execute("DELETE FROM blocks WHERE height > ?", height)
    $db.connection.execute("DELETE FROM wallet_transfers WHERE block_height > ?", height)
  end

  def validate_and_apply_block(block)
    validate(block)
    save_block(block)

    $logger.info("Finished validating and applying block ##{block.height}")
  end

  def address_has_enough_funds?(message_transaction)
    from = Digest::SHA256.hexdigest(message_transaction["from"])
    total = BigDecimal(message_transaction["amount"]) + BigDecimal(message_transaction["fee"])

    address_balance(from) > total
  end

  # Returns the balance of the SHA256 hashed address.
  # This implementation goes throught all previous transactions of the block
  # chain to calculate the balance. This is of course very inefficient but
  # sufficient for our purpose.
  def address_balance(address)
    total = $db.connection.execute(
      "SELECT amount FROM wallet_transfers WHERE destination_address = ?",
      address,
    ).flatten.map { |a| BigDecimal(a) }.reduce(&:+)

    spent_including_fees = $db.connection.execute(
      "SELECT fee, amount FROM wallet_transfers WHERE from_address = ?",
      address,
    ).flatten.map { |a| BigDecimal(a) }.reduce(&:+)

    total.to_i - spent_including_fees.to_i
  end

  # Validate all the cryptographical components of the transactions.
  # Therefore it doesn't include ensuring the wallet has the required funds to
  # make the transaction.
  def valid_cryptography?(transaction)
    # The signature of the message needs to be valid and come from the sender.
    if transaction["id"] != Digest::SHA256.hexdigest(transaction["signature"])
      $logger.warn("Transaction ID isn't the SHA256 of the signature")
      return false
    end

    # The signature should be valid.
    if transaction["message"]["type"] != "mining_reward"
      public_key = ECDSA::Format::PointOctetString.decode(
        Base58.base58_to_binary(transaction["message"]["from"]),
        ECDSA::Group::Secp256k1,
      )

      digest = Digest::SHA256.digest(transaction["message"].sort.to_h.to_json)

      signature = ECDSA::Format::SignatureDerString.decode(
        Base58.base58_to_binary(transaction["signature"])
      )

      if ECDSA.valid_signature?(public_key, digest, signature) == false
        $logger.warn("Transaction signature is invalid")
        return false
      end
    end
  end
end

