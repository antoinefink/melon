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
      @height,
      @previous_block_header_hash,
      @time.utc.to_s,
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
  # The parameters is used to provide a ime limit to the search for the nonce.
  def find_nonce(seconds)
    time_limit = Time.now + seconds
    @nonce = 0 if @nonce.nil?

    loop do
      if Time.now > time_limit
        return false
      end

      @block_header_hash = compute_block_header_hash

      if @block_header_hash[0, Blockchain::DIFFICULTY_LEVEL] == "0" * Blockchain::DIFFICULTY_LEVEL
        @block_header_hash = block_header_hash
        break
      end

      @nonce = nonce + 1
    end

    $logger.info "Found correct nonce: #{@block_header_hash}"

    return true
  end

  def transactions=(value)
    @transactions = value

    return if value.nil?
    @merkle_root = merkle_tree.root.value
  end

  def to_json(options = {})
    {
      height: @height,
      previous_block_header_hash: @previous_block_header_hash,
      block_header_hash: @block_header_hash,
      nonce: @nonce,
      time: @time,
      transactions: @transactions,
    }.to_json
  end

  private

  def merkle_tree
    MerkleTree.new(*transactions.map(&:to_json).sort { |a, b| a["id"] <=> b["id"] })
  end

  class << self
    def initialize_from_json(blockchain, block)
      Block.new(
        blockchain,
        height: block["height"],
        time: Time.parse(block["time"]),
        previous_block_header_hash: block["previous_block_header_hash"],
        block_header_hash: block["block_header_hash"],
        transactions: block["transactions"],
        nonce: block["nonce"],
        merkle_root: block["merkle_root"],
        )
    end
  end
end