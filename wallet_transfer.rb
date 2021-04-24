class WalletTransfer
  def initialize(id:, from_address: nil, destination_address: nil, amount:,
                 fee:, block_height:)
    @id = id
    @from_address = from_address
    @destination_address = destination_address
    @amount = amount
    @fee = fee
    @block_height = block_height
  end

  def insert
    $db.connection.execute(
      """INSERT INTO wallet_transfers
           (id, from_address, destination_address, amount, fee, block_height)
         VALUES (?, ?, ?, ?, ?, ?)""",
      [
        @id,
        @from_address,
        @destination_address,
        @amount,
        @fee,
        @block_height,
      ]
    )
  end

  class << self
    def find(id)
      result = $db.connection.execute("""
          SELECT
            id, from_address, destination_address, amount, fee, block_height
          FROM wallet_transfers
          WHERE id = ? LIMIT 1""",
        id).first
      return if result.nil?

      WalletTransfer.new(
        id: result[0],
        from_address: result[1],
        destination_address: result[2],
        amount: result[3],
        fee: result[5],
        block_height: result[6],
      )
    end
  end
end