class Node < Sinatra::Base
  set :logger, $logger
  set :port, ENV["MLN_PORT"] || 4567

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
end