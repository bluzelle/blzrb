require 'dotenv'
require_relative "../lib/bluzelle"

Dotenv.load('.env')

def debug
  if %w(f false n no 0).freeze.include?(ENV.fetch("DEBUG", '0')) then false else true end
end

def new_client
  Bluzelle::new_client({
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
end

def key_values_to_dict key_values
  ret = {}
  key_values.each do |key_value|
    ret[key_value['key']] = key_value['value']
  end
  ret
end
