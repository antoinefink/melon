DIFFICULTY_LEVEL = 4

class Mining
  def initialize(blockchain)
    @blockchain = blockchain
  end

  # Blockig method that will main the blockchain until canceled.
  def mine
    loop do
      block = build_block

      block.find_nonce

      @blockchain.save_and_broadcast(block)

      puts "Block #{block.height} successfuly mined 🎉"
    end
  end

  private

  # Builds a complete block except for the nonce.
  def build_block
    previous_block = @blockchain.previous_block

    transactions = gather_transactions

    Block.new(
      @blockchain,

      time: Time.now.utc,
      previous_block_header_hash: previous_block&.block_header_hash,
      height: previous_block&.height.to_i + 1,
      transactions: transactions,
    )
  end

  # In a functioning blockchain, we would listen for users wanting to add data
  # to the blockchain and include their transactions based on their size and
  # the fee they agree to pay to the miner. For this initial version, we are
  # generating random data.
  def gather_transactions
    [
      "Some say the world will end in fire,",
      "Some say in ice.",
      "From what I’ve tasted of desire",
      "I hold with those who favor fire.",
      "But if it had to perish twice,",
      "I think I know enough of hate",
      "To say that for destruction ice",
      "Is also great",
      "And would suffice.",
    ]
  end

  class << self
    def start
      Mining.new(Blockchain.start).mine
    end
  end
end

