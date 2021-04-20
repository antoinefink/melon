class Blockchain
  def previous_block
    previous_block = DB.connection.execute("""
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
    DB.connection.execute(
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

    block.transactions.each { |tx| record_transaction(block, tx) }
  end

  # Transactions can contain anything as long as they include a fee for the
  # miner and are signed by a sender with enough funds.
  #
  # We are going to record:
  # 1. The coin reward to the miner for having mined the block (the coinbase).
  # 2. If available, the transfer of fees to the miner as defined in the transactions.
  # 3. If available, the transfer of funds from the sender to the recipient.
  def record_transaction(block, transaction)
    Transaction.new(
      id: transaction.id,
      from_address: transaction.message[:from],
      destination_address: transaction.message[:destination],
      amount: transaction.message[:amount],
      fee: transaction.message[:fee],
      block_height: block.height,
    ).insert
  end
end

