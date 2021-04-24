require "sqlite3"
require "pry"
require "merkle_tree"
require "date"
require "digest"
require "json"
require "ecdsa"
require "securerandom"
require "fileutils"
require "base58"
require "bigdecimal"
require "sinatra/base"
require "logger"
require "httparty"

require "./db"
require "./block"
require "./blockchain"
require "./mining"
require "./wallet"
require "./transaction_builder"
require "./wallet_transfer"
require "./node"
require "./pending_transaction"

$logger = Logger.new(STDOUT)

# No arguments to the command means we'll show the user the list of all commands.
if ARGV.size == 0
  $logger.info "Welcome to the melon factory 🍈\n\n"
  $logger.info "Available commands:"
  $logger.info "\t node — Starts a node"
  $logger.info "\t mine — Starts a node that also performs mining"
  $logger.info "\t pry — A runtime developer console for debugging"
  $logger.info "\t submit_random_transactions — Submits a transaction to all peers every second"

  return
end

# Run the required command.
case ARGV.first.to_s.downcase
when "node"
  $db = DB.new

  blockchain = Blockchain.new

  Thread.new do
    begin
      loop do
        sleep 5
        blockchain.find_higher_blocks_on_the_network
      end
    rescue => e
      $logger.error e
    end
  end

  Node.run!



when "mine"
  $db = DB.new

  # The mining process starts in a thread. This approach isn't the most elegant
  # but it makes it possible to have the entire application run together which
  # is easier for our purpose.
  Thread.new do
    begin
      sleep 2 # A small delay wil lensure Sinatra starts successfully
      Mining.start
    rescue => e
      $logger.error e
    end
  end

  Node.run!

when "pry"
  $db = DB.new
  blockchain = Blockchain.new

  binding.pry

when "submit_random_transactions"
  mining_wallet = Wallet.load_or_create("mining")

  loop do
    # The destination address is random as we're only testing.
    destination = Digest::SHA256.hexdigest(SecureRandom.random_number(100000000000).to_s)
    amount = BigDecimal("0.00" + SecureRandom.random_number(10000).to_s)

    transaction = mining_wallet.generate_transaction(
      destination,
      amount.to_s("F"),
      (amount / 100).to_s("F"),
    )

    ENV["MLN_PEERS"].to_s.split(",").each do |peer|
      response = HTTParty.post("http://#{peer}/transactions/submit",
        body: transaction.to_json,
        headers: { "Content-Type": "application/json" },
      )

      if response.code != 200
        $logger.error("Failed submitting transaction: #{response.message}")
      else
        $logger.info("Submitted one transaction to #{peer}")
      end
    end

    sleep 1
  end

else
  raise "Unknown command."
end