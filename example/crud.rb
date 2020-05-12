require "dotenv"
require_relative "../lib/bluzelle"

Dotenv.load(".env")

def debug
  if %w(f false n no 0).freeze.include?(ENV.fetch("DEBUG", '0')) then false else true end
end

client = Bluzelle::new_client({
  "address" =>  ENV.fetch("ADDRESS", nil),
  "mnemonic" => ENV.fetch("MNEMONIC", nil),
  "uuid" =>     ENV.fetch("UUID", nil),
  "endpoint" => ENV.fetch("ENDPOINT", ""),
  "chain_id" =>  ENV.fetch("CHAIN_ID", nil),
  "debug" => debug,
})

key = "#{Time.now.to_i}"
value = "bar"

puts 'creating key'
client.create key, value, lease: 1
puts 'created key'
puts 'reading key'
value = client.read key
puts 'read key'
puts 'updating key'
client.update key, 'baz'
puts 'updated key'
puts 'deleting key'
#client.delete key
