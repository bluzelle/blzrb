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
    msg = e.api_error
  end
  msg.to_json
end

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

  json client.public_send(method, *args)
end

puts "serving at #{PORT}"
