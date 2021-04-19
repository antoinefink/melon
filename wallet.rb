class Wallet
  def initialize(private_key)
    @private_key = private_key
  end

  def public_key
    pk = group.generator.multiply_by_scalar(@private_key)
    pk_string = ECDSA::Format::PointOctetString.encode(pk, compression: true)
    Base58.binary_to_base58(pk_string, :bitcoin)
  end

  # Signs a message as a DER string and return it encoded in Base58.
  def sign(message)
    raise "Only strings can be signed" unless message.is_a?(String)

    digest = Digest::SHA256.digest(message)
    signature = nil
    while signature.nil?
      temp_key = 1 + SecureRandom.random_number(group.order - 1)
      signature = ECDSA.sign(group, @private_key, digest, temp_key)
    end

    signature_der_string = ECDSA::Format::SignatureDerString.encode(signature)

    Base58.binary_to_base58(signature_der_string)
  end

  def generate_transaction(destination, amount)
    transaction = Transaction.new(
      wallet: self,
    )

    transaction.set_cryptocurrency_message(destination, amount)

    transaction
  end

  private

  def group
    ECDSA::Group::Secp256k1
  end

  class << self
    def load_or_create(name)
      FileUtils.mkdir_p("keys")

      group = ECDSA::Group::Secp256k1

      # We first try to load an existing private key.
      if File.file?("./keys/#{name}.key") == false
        private_key = 1 + SecureRandom.random_number(group.order - 1)
        File.write("./keys/#{name}.key", Base58.int_to_base58(private_key))
      end

      # The key doesn't exist, we create a new one and store it for later use.
      private_key = File.read("./keys/#{name}.key").to_i

      raise "Failed loading the private key" if private_key == 0

      Wallet.new(private_key)
    end
  end
end