class Node < Sinatra::Base
  configure do
    set :logger, $logger
    set :port, ENV["MLN_PORT"] || 4567
    enable :logging, :dump_errors
  end

  @@blockchain = Blockchain.new

  get "/" do
    "🍈"
  end

  get "/version" do
    "0.1.0"
  end

  get "/blocks/last" do
    content_type :json
    @@blockchain.last_block.to_json
  end

  get "/blocks/:height" do
    content_type :json
    @@blockchain.find_block_by_height(params["height"]).to_json
  end

  post "/transactions/submit" do
    transaction = JSON.parse(request.body.read)

    if transaction["message"]["type"] != "funds_transfer"
      halt(400, "Transaction has an invalid type")
    end

    if @@blockchain.valid_cryptography?(transaction) == false
      halt(400, "Transaction is cryptography is invalid")
    end

    if @@blockchain.address_has_enough_funds?(transaction["message"]) == false
      halt(400, "The sender's address doesn't have enough funds")
    end

    PendingTransaction.create(transaction)

    $logger.info("Received one pending transaction (#{transaction["id"]})")

    "accepted"
  end
end