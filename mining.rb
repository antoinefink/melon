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

        break if block.find_nonce(10)
      end

      @blockchain.save_block(block)

      $logger.info "Block #{block.height} successfuly mined with #{block.transactions.size} transaction 🎉"
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

  # For their work, miners are allowed to add a transaction sending one MLN to
  # an address of their choosing.
  # The address is hashed as a precautionary measure.
  def mining_reward_transcation(transactions)
    transaction = TransactionBuilder.new(
      wallet: @wallet,
    )

    fees = transactions.map { |tx| BigDecimal(tx["message"]["fee"]) }.reduce(:+)

    transaction.set_mining_message(@wallet.destination_address, fees)

    transaction
  end

  def gather_transactions
    transactions = PendingTransaction.first(100).to_a

    # Blocks might have been mined since the transaction was submited. We
    # therefore ensure the wallet still has the necessary funds and that the
    # ID of the transaction isn't already in the blockchain.
    transactions.reject do |transaction|
      @blockchain.address_has_enough_funds?(transaction["message"]) == false ||
      WalletTransfer.find(transaction["id"]).nil? == false
    end
  end

  class << self
    def start
      $logger.info "Starting the mining ⛏"
      Mining.new(Blockchain.new).mine
    end
  end
end

