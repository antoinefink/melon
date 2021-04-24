class Mining
  def initialize(blockchain)
    @blockchain = blockchain
    @wallet = Wallet.load_or_create("mining")
  end

  # Blockig method that will main the blockchain until canceled.
  def mine
    loop do
      block = build_block

      time_limit = 10 # Seconds
      loop do
        @blockchain.find_higher_blocks_on_the_network

        block.find_nonce(10)
        break unless block.nonce.nil?
      end

      @blockchain.save_block(block)

      $logger.info "Block #{block.height} successfuly mined 🎉"
    end
  end

  private

  # Builds a complete block except for the nonce.
  def build_block
    previous_block = @blockchain.last_block

    # We always include a mining reward. On the genesis block, that's the only
    # transaction to be present.
    transactions = previous_block.nil? ? [] : gather_transactions
    transactions << mining_reward_transcation(transactions)

    Block.new(
      @blockchain,

      time: Time.now.utc,
      previous_block_header_hash: previous_block&.block_header_hash,
      height: previous_block&.height.to_i + 1,
      transactions: transactions.map(&:to_h),
    )
  end

  # In a functioning blockchain, we would listen for users wanting to add data
  # to the blockchain and include their transactions based on their size and
  # the fee they agree to pay to the miner. For this initial version, we are
  # generating random data.
  def gather_transactions
    [
      generate_random_transaction,
      generate_random_transaction,
      generate_random_transaction,
      generate_random_transaction,
    ]
  end

  # For their work, miners are allowed to add a transaction sending one MLN to
  # an address of their choosing.
  # The address is hashed as a precautionary measure.
  def mining_reward_transcation(transactions)
    transaction = TransactionBuilder.new(
      wallet: @wallet,
    )

    fees = transactions.map { |tx| BigDecimal(tx.message["fee"]) }.reduce(:+)

    transaction.set_mining_message(@wallet.destination_address, fees)

    transaction
  end

  # This is a temporary method to make testing easier. It sends a random tiny
  # amount of MLN from the miner's wallet to a random address.
  #
  # The origin address is the Base58 encoded public key. It shouldn't be hashed
  # to allow the verification of the signature.
  # On the other hand, the destination address is hashed to improve security.
  #
  def generate_random_transaction
    mining_wallet = Wallet.load_or_create("mining")

    destination = Digest::SHA256.hexdigest(SecureRandom.random_number(100000000000).to_s)
    amount = BigDecimal("0.00" + SecureRandom.random_number(10000).to_s)

    mining_wallet.generate_transaction(
      destination,
      amount.to_s("F"),
      (amount / 100).to_s("F"),
    )
  end

  class << self
    def start
      $logger.info "Starting the mining ⛏"
      Mining.new(Blockchain.new).mine
    end
  end
end

