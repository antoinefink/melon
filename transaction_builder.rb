class TransactionBuilder
  attr_reader :message, :signature

  def initialize(wallet:, message: nil)
    @message = message
    @wallet = wallet
  end

  def to_json(options = {})
    to_h.to_json
  end

  def to_h
    sign! if @signature.nil?

    {
      "id" => id,
      "signature" => @signature,
      "message" => @message,
    }
  end

  def sign!
    # For improved consistency, the message is sorted.
    @signature = @wallet.sign(@message.sort.to_h.to_json)
  end

  def id
    return nil if @signature.nil?

    Digest::SHA256.hexdigest(@signature)
  end

  # Sets the message to be a regularly exchange of cryptocurrency from one
  # address to another.
  def set_cryptocurrency_message(destination, amount, fee)
    @message = {
      "type" => "funds_transfer",
      "from" => @wallet.public_key,
      "destination" => destination,
      "amount" => amount,
      "fee" => fee,
    }
  end

  # Sets the message to be the mining reward which will include the sum of all
  # the fees of the transactions in the block as well as one new coin.
  def set_mining_message(destination, fees)
    fees = BigDecimal(0) if fees.nil?

    @message = {
      "type" => "mining_reward",
      "destination" => destination,
      "amount" => (fees + 1).to_s("F"),
    }
  end
end