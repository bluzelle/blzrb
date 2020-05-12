# frozen_string_literal: true

require 'sinatra'
#require 'sinatra/reloader'# if development?
require 'sinatra/json'
require 'dotenv'
require_relative '../lib/bluzelle'

Dotenv.load('.env')

ADDRESS = ENV.fetch('ADDRESS', nil)
MNEMONIC = ENV.fetch('MNEMONIC', nil)

client = Bluzelle.new_client({
 'address' => ADDRESS,
 'mnemonic' => MNEMONIC,
 'uuid' => ENV.fetch('UUID', nil),
 'endpoint' => ENV.fetch('ENDPOINT', ''),
 'chain_id' => ENV.fetch('CHAIN_ID', nil),
 'gas_info' => {
   'max_fee' => 4_000_001
 },
 'debug' => true
})

PORT = ENV.fetch('PORT', 4563)
set :port, PORT

# This is needed for testing, otherwise the default
# error handler kicks in
set :environment, :production

error do
  content_type :json
  status 400 # or whatever

  e = env['sinatra.error']
  msg = e.message
  if e.instance_of? Bluzelle::APIError
    msg = e.apiError
  end
  msg.to_json
end

METHODS_WITH_NAMED_ARGS = {
  "create" => {:lease_info => 2, :gas_info => 3},
  "update" => {:lease_info => 2, :gas_info => 3},
  "delete" => {:gas_info => 1},
  "rename" => {:gas_info => 2},
  "delete_all" => {:gas_info => 0},
  "multi_update" => {:gas_info => 1},
  "renew_lease" => {:gas_info => 2},
  "renew_all_leases" => {:gas_info => 1},
  "tx_read" => {:gas_info => 1},
  "tx_has" => {:gas_info => 1},
  "tx_count" => {:gas_info => 0},
  "tx_keys" => {:gas_info => 0},
  "tx_key_values" => {:gas_info => 0},
  "tx_get_lease" => {:gas_info => 1},
  "tx_get_n_shortest_leases" => {:gas_info => 1},
}

post '/' do
  # request.body.rewind
  req = JSON.parse request.body.read

  unless req.key?('method') && req.key?('args')
    raise 'both method and args are required'
  end

  method = req['method']
  args = req['args']

  raise('args should be a list') if args.class.equal?(Hash)

  if !client.respond_to? method
    raise "unknown method #{method}"
  end

  kwargs = Hash.new

  method_named_args = METHODS_WITH_NAMED_ARGS.fetch(method, nil)
  if method_named_args
    lease_info_index = method_named_args.fetch(:lease_info, nil)
    gas_info_index = method_named_args.fetch(:gas_info, nil)
    original_args = args[0..args.length]
    if gas_info_index && original_args.size > gas_info_index
      kwargs[:gas_info] = original_args[gas_info_index]
      args.delete_at gas_info_index
    end
    if lease_info_index && original_args.size > lease_info_index
      kwargs[:lease_info] = original_args[lease_info_index]
      args.delete_at lease_info_index
    end
  end
  result = client.public_send(method, *args, **kwargs)
  if result == nil
    nil
  end
  json result
end

puts "serving at #{PORT}"
