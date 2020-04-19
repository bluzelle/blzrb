# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'digest'
require 'logger'
require 'net/http'
require 'securerandom'
require 'ecdsa'
require 'bip_mnemonic'
require 'money-tree'
require 'secp256k1'
require_relative 'bech32'

DEFAULT_ENDPOINT = 'http://localhost:1317'
DEFAULT_CHAIN_ID = 'bluzelle'
HD_PATH = "m/44'/118'/0'/0/0"
ADDRESS_PREFIX = 'bluzelle'
TX_COMMAND = '/txs'
TOKEN_NAME = 'ubnt'
PUB_KEY_TYPE = 'tendermint/PubKeySecp256k1'
BROADCAST_MAX_RETRIES = 10
BROADCAST_RETRY_INTERVAL_SECONDS = 1
MSG_KEYS_ORDER = %w[
  Key
  KeyValues
  Lease
  N
  NewKey
  Owner
  UUID
  Value
].freeze

module Bluzelle
  class OptionsError < StandardError
  end

  class APIError < StandardError
  end

  def self.new_client options
    raise OptionsError, 'address is required' unless options.fetch('address', nil)
    raise OptionsError, 'mnemonic is required' unless options.fetch('mnemonic', nil)

    gas_info = options.fetch('gas_info', {})
    unless gas_info.class.equal?(Hash)
      raise OptionsError, 'gas_info should be a dict of {gas_price, max_fee, max_gas}'
    end

    gas_info_keys = %w[gas_price max_fee max_gas]
    gas_info_keys.each do |k|
      v = gas_info.fetch(k, 0)
      unless v.class.equal?(Integer)
        raise OptionsError, 'gas_info[%s] should be an int' % k
      end

      gas_info[k] = v
    end

    options['debug'] = false unless options.fetch('debug', false)
    options['chain_id'] = DEFAULT_CHAIN_ID unless options.fetch('chain_id', nil)
    options['endpoint'] = DEFAULT_ENDPOINT unless options.fetch('endpoint', nil)

    c = Client.new options
    c.setup_logging
    c.set_private_key
    c.verify_address
    c.set_account
    c
  end

  private

  class Client
    def initialize(options)
      @options = options
    end

    def setup_logging
      @logger = Logger.new(STDOUT)
      @logger.level = if @options['debug'] then Logger::DEBUG else Logger::FATAL end
    end

    def set_private_key
      seed = BipMnemonic.to_seed(mnemonic: @options['mnemonic'])
      master = MoneyTree::Master.new(seed_hex: seed)
      @wallet = master.node_for_path(HD_PATH)
    end

    def verify_address
      b = Digest::RMD160.digest(Digest::SHA256.digest(@wallet.public_key.compressed.to_bytes))
      address = Bech32.encode(ADDRESS_PREFIX, Bech32.convert_bits(b, from_bits: 8, to_bits: 5, pad: true))
      if address != @options['address']
        raise OptionsError, 'bad credentials(verify your address and mnemonic)'
      end
    end

    def set_account
      @account = read_account
    end

    # query

    def read_account
      url = "/auth/accounts/#{@options['address']}"
      api_query(url)['result']['value']
    end

    def read(key)
      url = "/crud/read/#{@options["uuid"]}/#{key}"
      api_query(url)["result"]["value"]
    end

    def proven_read(key)
      url = "/crud/pread/#{@options["uuid"]}/#{key}"
      api_query(url)["result"]["value"]
    end

    def has(key)
      url = "/crud/has/#{@options["uuid"]}/#{key}"
      api_query(url)["result"]["has"]
    end

    def count()
      url = "/crud/count/#{@options["uuid"]}"
      api_query(url)["result"]["count"].to_i
    end

    def keys()
      url = "/crud/keys/#{@options["uuid"]}"
      api_query(url)["result"]["keys"]
    end

    def key_values()
      url = "/crud/keyvalues/#{@options["uuid"]}"
      api_query(url)["result"]["keyvalues"]
    end

    # mutate

    def create(key, value, lease: 0)
      send_transaction('post', '/crud/create', { 'Key' => key, 'Lease' => lease.to_s, 'Value' => value })
    end

    def update(key, value, lease: nil)
      payload = {"Key" => key}
      payload["Lease"] = lease.to_s if lease.is_a? Integer
      payload["Value"] = value
      send_transaction("post", "/crud/update", payload)
    end

    def delete(key)
      send_transaction("delete", "/crud/delete", {"Key" => key})
    end

    def rename(key, new_key)
      send_transaction("post", "/crud/rename", {"Key" => key, "NewKey" => new_key})
    end

    #

    def api_query(endpoint)
      url = @options['endpoint'] + endpoint
      @logger.debug("querying url(#{url})...")
      response = Net::HTTP.get_response URI(url)
      data = JSON.parse(response.body)
      error = get_response_error(data)
      raise error if error
      @logger.debug("response (#{data})...")
      data
    end

    def api_mutate(method, endpoint, payload)
      url = @options['endpoint'] + endpoint
      @logger.debug("mutating url(#{url}), method(#{method})")
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      if method == "delete"
        request = Net::HTTP::Delete.new(uri.request_uri)
      else
        request = Net::HTTP::Post.new(uri.request_uri)
      end
      request['Accept'] = 'application/json'
      request.content_type = 'application/json'
      data = Bluzelle::json_dumps payload
      @logger.debug("data(#{data})")
      request.body = data
      response = http.request(request)
      @logger.debug("response (#{response.body})...")
      data = JSON.parse(response.body)
      error = get_response_error(data)
      raise error if error
      data
    end

    def send_transaction(method, endpoint, payload)
      @broadcast_retries = 0
      txn = validate_transaction(method, endpoint, payload)
      broadcast_transaction(txn)
    end

    def validate_transaction(method, endpoint, payload)
      address = @options['address']
      payload = payload.merge({
        'BaseReq' => {
          'chain_id' => @options['chain_id'],
          'from' => address
        },
        'Owner' => address,
        'UUID' => @options['uuid']
      })
      api_mutate(method, endpoint, payload)['value']
    end

    def broadcast_transaction(data)
      # fee
      fee = data['fee']
      fee_gas = fee['gas'].to_i
      gas_info = @options['gas_info']
      if gas_info['max_gas'] != 0 && fee_gas > gas_info['max_gas']
        fee['gas'] = gas_info['max_gas'].to_s
      end
      if gas_info['max_fee'] != 0
        fee['amount'] = [{ 'denom' => TOKEN_NAME, 'amount' => gas_info['max_fee'].to_s }]
      elsif gasInfo['gas_price'] != 0
        fee['amount'] = [{ 'denom' => TOKEN_NAME, 'amount' => (fee_gas * gas_info['gas_price']).to_s }]
      end

      # sort
      txn = build_txn(
        fee: fee,
        msg: data['msg'][0]
      )

      # signatures
      txn['signatures'] = [{
        'account_number' => @account['account_number'].to_s,
        'pub_key' => {
          'type' => PUB_KEY_TYPE,
          'value' => Bluzelle::base64_encode(@wallet.public_key.compressed.to_bytes)
        },
        'sequence' => @account['sequence'].to_s,
        'signature' => sign_transaction(txn)
      }]

      payload = { 'mode' => 'block', 'tx' => txn }
      response = api_mutate('post', TX_COMMAND, payload)
      unless response.fetch('code', nil)
        @account['sequence'] += 1
        if response.fetch('data', nil)
          return [response['data']].pack('H*')
        end
        return
      end

      raw_log = response["raw_log"]
      if raw_log.include?("signature verification failed")
        @broadcast_retries += 1
        @logger.warn("transaction failed ... retrying(#{@broadcast_retries}) ...")
        if @broadcast_retries >= BROADCAST_MAX_RETRIES
          raise APIError, "transaction failed after max retry attempts"
        end

        sleep BROADCAST_RETRY_INTERVAL_SECONDS
        set_account()
        broadcast_transaction(txn)
        return
      end

      raise APIError, raw_log
    end

    def sign_transaction(txn)
      payload = {
        'account_number' => @account['account_number'].to_s,
        'chain_id' => @options['chain_id'],
        'fee' => txn['fee'],
        'memo' => txn['memo'],
        'msgs' => txn['msg'],
        'sequence' => @account['sequence'].to_s
      }
      payload = Bluzelle::json_dumps(payload)

      pk = Secp256k1::PrivateKey.new(privkey: @wallet.private_key.to_bytes, raw: true)
      rs = pk.ecdsa_sign payload
      r = rs.slice(0, 32).read_string.reverse
      s = rs.slice(32, 32).read_string.reverse
      sig = "#{r}#{s}"
      Bluzelle::base64_encode sig
    end

    def build_txn(fee:, msg:)
      # TODO: find a better way to sort
      fee_amount = fee['amount'][0]
      txn = {
        'fee' => {
          "amount" => [
            {
              "amount" => fee_amount['amount'],
              "denom" => fee_amount['denom']
            }
          ],
          "gas" => fee['gas']
        },
        'memo' => Bluzelle::make_random_string(32)
      }
      msg_value = msg['value']
      new_msg_value = {}
      MSG_KEYS_ORDER.each do |key|
        val = msg_value.fetch(key, nil)
        new_msg_value[key] = val if val
      end
      txn['msg'] = [
        {
          "type" => msg['type'],
          "value" => new_msg_value
        }
      ]
      txn
    end

    def get_response_error(response)
      error = response['error']
      return APIError.new(error) if error
    end
  end

  def self.base64_encode(b)
    Base64.strict_encode64 b
  end

  def self.hex_to_bin(h)
    Secp256k1::Utils.decode_hex h
  end

  def self.bin_to_hex(b)
    Secp256k1::Utils.encode_hex b
  end

  def self.make_random_string(size)
    SecureRandom.alphanumeric size
  end

  def self.json_dumps(h)
    JSON.dump h
    # h.to_json
    # Hash[*h.sort.flatten].to_json
  end
end
