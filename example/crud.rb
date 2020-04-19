require "dotenv"
require_relative "../lib/bluzelle"

Dotenv.load(".env")

def debug
  if %w(f false n no 0).freeze.include?(ENV.fetch("DEBUG", '0')) then false else true end
end

client = Bluzelle.new({
  "address" =>  ENV.fetch("ADDRESS", nil),
  "mnemonic" => ENV.fetch("MNEMONIC", nil),
  "uuid" =>     ENV.fetch("UUID", nil),
  "endpoint" => ENV.fetch("ENDPOINT", ""),
  "chain_id" =>  ENV.fetch("CHAIN_ID", nil),
  "gas_info" => {
    "max_fee" => 4000001,
  },
  "debug" => debug,
})

key = "#{Time.now.to_i}"
value = "bar"

puts "creating #{key}=#{value}"
client.create key, value
puts "created key"
