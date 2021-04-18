class Block
  attr_accessor :height, :previous_block_hash, :block_hash, :nonce, :time

  def initialize(blockchain, height:, previous_block_hash: nil, block_hash: nil, nonce: nil, time:)
    @blockchain = blockchain

    @height = height
    @previous_block_hash = previous_block_hash
    @block_hash = block_hash
    @nonce = nonce
    @time = time
  end

  # Returns the hash of the block header which has the following composition:
  # * Previous block header
  # * Time (X bytes)
  # * Nonce (X bytes)
  def compute_block_hash
    Digest::SHA256.hexdigest([
      @previous_block_hash,
      @time,
      @nonce,
    ].join("|"))
  end

  # Finds the once matching the currentdifficulty level of the Blockchain.
  def find_nonce
    @nonce = 0

    loop do
      @block_hash = compute_block_hash

      if block_hash[0, DIFFICULTY_LEVEL] == "0" * DIFFICULTY_LEVEL
        @block_hash = block_hash
        break
      end

      @nonce = nonce + 1
    end

    puts "Found correct nonce: #{@block_hash}"
  end
end