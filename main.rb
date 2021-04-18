require "sqlite3"
require "pry"
require "merkle_tree"
require "date"
require "digest"
require "json"
require "ecdsa"
require "securerandom"

require "./block"
require "./blockchain"
require "./mining"


# No arguments to the command means we'll show the user the list of all commands.
if ARGV.size == 0
  puts "Welcome to the melon factory 🍈\n\n"
  puts "Available commands:"
  puts "\t node — Starts a node"
  puts "\t mine — Starts a node that also performs mining"

  return
end

# Run the required command.
case ARGV.first.to_s.downcase
when "node"
  raise "Not implemented just yet!"

when "mine"
  puts "Starting the mining ⛏"
  Mining.start

when "pry"
  binding.pry

else
  raise "Unknown command."
end