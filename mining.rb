DIFFICULTY_LEVEL = 4

class Mining
  def initialize(blockchain)
    @blockchain = blockchain
  end

  # Blockig method that will main the blockchain until canceled.
  def mine
    loop do
      block = build_block

      block.find_nonce

      @blockchain.save_and_broadcast(block)

      puts "Block #{block.height} successfuly mined 🎉"
    end
  end

  private

  # Builds a complete block except for the nonce.
  def build_block
    previous_block = @blockchain.previous_block

    transactions = gather_transactions
    transactions << mining_reward_transcation

    Block.new(
      @blockchain,

      time: Time.now.utc,
      previous_block_header_hash: previous_block&.block_header_hash,
      height: previous_block&.height.to_i + 1,
      transactions: transactions,
    )
  end

  # In a functioning blockchain, we would listen for users wanting to add data
  # to the blockchain and include their transactions based on their size and
  # the fee they agree to pay to the miner. For this initial version, we are
  # generating random data.
  def gather_transactions
    [
      "Some say the world will end in fire",
      "My random number: " + SecureRandom.random_number(10000000).to_s,
      generate_random_transaction,
    ]
  end

  # For their work, miners are allowed to add a transaction sending one MLN to
  # an address of their choosing.
  # The address is hashed as a precautionary measure.
  def mining_reward_transcation
    {
      "type": "mining_reward",
      "address": Digest::SHA256.hexdigest(mining_reward_address),
    }
  end

  # Loads or generate a private key and then deducts the public key that will
  # be used as an address.
  def mining_reward_address
    FileUtils.mkdir_p(File.dirname("keys"))

    group = ECDSA::Group::Secp256k1

    # We first try to load an existing private key.
    if File.file?("./keys/mining.key") == false
      private_key = 1 + SecureRandom.random_number(group.order - 1)
      File.write("./keys/mining.key", Base58.int_to_base58(private_key))
    end

    # The key doesn't exist, we create a new one and store it for later use.
    private_key = File.read("./keys/mining.key").to_i

    raise "Failed loading the private key" if private_key == 0

    public_key = group.generator.multiply_by_scalar(private_key)
    public_key_string = ECDSA::Format::PointOctetString.encode(public_key, compression: true)
    Base58.binary_to_base58(public_key_string, :bitcoin)
  end

  class << self
    def start
      Mining.new(Blockchain.start).mine
    end
  end
end

