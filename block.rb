class Block
  attr_accessor :height, :previous_block_header_hash, :block_header_hash,
                :nonce, :time, :transactions, :merkle_root

  def initialize(blockchain, height:, time:, previous_block_header_hash: nil,
                 block_header_hash: nil, transactions: nil, nonce: nil,
                 merkle_root: nil)
    @blockchain = blockchain

    self.height = height
    self.previous_block_header_hash = previous_block_header_hash
    self.block_header_hash = block_header_hash
    self.nonce = nonce
    self.time = time
    self.transactions = transactions
  end

  def block_header
    [
      @previous_block_header_hash,
      @time,
      @merkle_root,
      @nonce,
    ].join("|")
  end

  # Returns the hash of the block header which has the following composition:
  # * Previous block header
  # * Time (X bytes)
  # * Nonce (X bytes)
  def compute_block_header_hash
    Digest::SHA256.hexdigest(block_header)
  end

  # Finds the nonce matching the current difficulty level of the Blockchain.
  def find_nonce
    @nonce = 0

    loop do
      @block_header_hash = compute_block_header_hash

      if @block_header_hash[0, DIFFICULTY_LEVEL] == "0" * DIFFICULTY_LEVEL
        @block_header_hash = block_header_hash
        break
      end

      @nonce = nonce + 1
    end

    puts "Found correct nonce: #{@block_header_hash}"
  end

  def transactions=(value)
    @transactions = value
    @merkle_root = merkle_tree.root.value
  end

  private

  def merkle_tree
    MerkleTree.new(*transactions)
  end
end