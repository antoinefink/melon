class Transaction
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
    DB.connection.execute(
      """INSERT INTO transactions
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
      result = DB.connection.execute("""
          SELECT
            id, from_address, destination_address, amount, fee, block_height
          FROM transactions
          WHERE id = ? LIMIT 1""",
        id).first
      return if result.nil?

      Transaction.new(
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