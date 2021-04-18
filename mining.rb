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

    Block.new(
      @blockchain,

      time: DateTime.now,
      previous_block_hash: previous_block&.block_hash,
      height: previous_block&.height + 1 || 1,
    )
  end

  class << self
    def start
      Mining.new(Blockchain.start).mine
    end
  end
end

