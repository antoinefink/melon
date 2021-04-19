class Transaction
  def initialize(wallet:, message: nil)
    @message = message
    @wallet = wallet
  end


  def to_json(options = {})
    sign! if @signature.nil?

    {
      id: id,
      signature: @signature,
      message: @message,
    }.to_json
  end

  def sign!
    # For improved consistency, the message is sorted.
    @signature = @wallet.sign(@message.sort.to_h.to_json)
  end

  def id
    return nil if @signature.nil?

    Digest::SHA256.hexdigest(@signature)
  end

  def set_cryptocurrency_message(destination, amount)
    @message = {
      from: @wallet.public_key,
      destination: destination,
      amount: amount,
      fee: 0,
    }
  end
end