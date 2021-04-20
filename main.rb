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

require "./db"
require "./block"
require "./blockchain"
require "./mining"
require "./wallet"
require "./transaction_builder"
require "./transaction"
require "./node"

$logger = Logger.new(STDOUT)

# No arguments to the command means we'll show the user the list of all commands.
if ARGV.size == 0
  $logger.info "Welcome to the melon factory 🍈\n\n"
  $logger.info "Available commands:"
  $logger.info "\t node — Starts a node"
  $logger.info "\t mine — Starts a node that also performs mining"

  return
end

# Run the required command.
case ARGV.first.to_s.downcase
when "node"
  Node.run!

when "mine"
  DB.load_schema

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
  binding.pry

else
  raise "Unknown command."
end