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
    $db.connection.execute(
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
      result = $db.connection.execute("""
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

    # Validate all the cryptographical components of the transactions.
    # Therefore it doesn't include ensuring the wallet has the required funds to
    # make the transaction.
    def valid_cryptography?(transaction)
      # The signature of the message needs to be valid and come from the sender.
      if transaction["id"] != Digest::SHA256.hexdigest(transaction["signature"])
        $logger.warn("Transaction ID isn't the SHA256 of the signature")
        return false
      end

      # The signature should be valid.
      if transaction["message"]["type"] != "mining_reward"
        public_key = ECDSA::Format::PointOctetString.decode(
          Base58.base58_to_binary(transaction["message"]["from"]),
          ECDSA::Group::Secp256k1,
        )

        digest = Digest::SHA256.digest(transaction["message"].sort.to_h.to_json)

        signature = ECDSA::Format::SignatureDerString.decode(
          Base58.base58_to_binary(transaction["signature"])
        )

        if ECDSA.valid_signature?(public_key, digest, signature) == false
          $logger.warn("Transaction signature is invalid")
          return false
        end
      end
    end
  end
end