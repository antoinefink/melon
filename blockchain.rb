class Blockchain
  def initialize(db)
    @db = db
  end

  def previous_block
    previous_block = @db.execute("""
      SELECT
        height, previous_block_header_hash, block_header_hash, nonce, time, transactions
      FROM blocks
      ORDER BY height DESC
      LIMIT 1
    """).first

    # Not finding a block means we're mining the first one!
    return if previous_block.nil?

    Block.new(
      self,

      height: previous_block[0],
      previous_block_header_hash: previous_block[1],
      block_header_hash: previous_block[2],
      nonce: previous_block[3],
      time: DateTime.parse(previous_block[4]),
    )
  end

  def save_and_broadcast(block)
    @db.execute(
      """INSERT INTO blocks
           (height, previous_block_header_hash, block_header_hash, nonce, time, merkle_root, transactions)
         VALUES (?, ?, ?, ?, ?, ?, ?)""",
      [
        block.height,
        block.previous_block_header_hash,
        block.block_header_hash,
        block.nonce,
        block.time.iso8601(3),
        block.merkle_root,
        block.transactions.to_json,
      ]
    )
  end

  class << self
    # Start the blockchain by loading the DB.
    def start
      load_db

      Blockchain.new(@db)
    end

    private

    def load_db
      @db = SQLite3::Database.new "melon.db"

      rows = @db.execute(%(SELECT name FROM sqlite_master WHERE type='table' AND name='blocks';))

      # No rows means the table containing blocks doesn't exist.
      return if rows.size > 0

      @db.execute(File.open("schema.sql").read)
    end
  end
end

