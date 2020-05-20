# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'digest'
require 'logger'
require 'cgi'
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
BLOCK_TIME_IN_SECONDS = 5

KEY_MUST_BE_A_STRING = "Key must be a string"
NEW_KEY_MUST_BE_A_STRING = "New key must be a string"
VALUE_MUST_BE_A_STRING = "Value must be a string"
ALL_KEYS_MUST_BE_STRINGS = "All keys must be strings"
ALL_VALUES_MUST_BE_STRINGS = "All values must be strings"
INVALID_LEASE_TIME = "Invalid lease time"
INVALID_VALUE_SPECIFIED = "Invalid value specified"
ADDRESS_MUST_BE_A_STRING = "address must be a string"
MNEMONIC_MUST_BE_A_STRING = "mnemonic must be a string"
UUID_MUST_BE_A_STRING = "uuid must be a string"
INVALID_TRANSACTION = "Invalid transaction."

module Bluzelle
  class OptionsError < StandardError
  end

  class APIError < StandardError
    attr_reader :api_error, :api_response
    def initialize(msg, api_error = nil, api_response = nil)
      @api_error = api_error || msg
      @api_response = api_response
      super(msg)
    end
  end

  def self.new_client options
    mnemonic = options.fetch('mnemonic', nil)
    raise OptionsError, 'mnemonic is required' unless mnemonic
    if !mnemonic.instance_of? String
      raise OptionsError.new(MNEMONIC_MUST_BE_A_STRING)
    end

    uuid = options.fetch('uuid', nil)
    raise OptionsError, 'uuid is required' unless uuid
    if !uuid.instance_of? String
      raise OptionsError.new(UUID_MUST_BE_A_STRING)
    end

    options['debug'] = false unless options.fetch('debug', false)
    options['chain_id'] = DEFAULT_CHAIN_ID unless options.fetch('chain_id', nil)
    options['endpoint'] = DEFAULT_ENDPOINT unless options.fetch('endpoint', nil)

    c = Client.new options
    c.setup_logging
    c.set_private_key
    c.set_address
    c.set_account
    c
  end

  private

  class Client
    attr_reader :address
    def initialize(options)
      @options = options
      @address = ""
      @account = nil
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

    def set_address
      b = Digest::RMD160.digest(Digest::SHA256.digest(@wallet.public_key.compressed.to_bytes))
      @address = Bech32.encode(ADDRESS_PREFIX, Bech32.convert_bits(b, from_bits: 8, to_bits: 5, pad: true))
    end

    def set_account
      @bluzelle_account = account
    end

    #

    def account
      url = "/auth/accounts/#{@address}"
      api_query(url)['result']['value']
    end

    def version()
      url = "/node_info"
      api_query(url)["application_version"]["version"]
    end

    # mutate

    def create(key, value, gas_info, lease_info = nil)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      if !value.instance_of? String
        raise APIError.new(VALUE_MUST_BE_A_STRING)
      end
      payload = {"Key" => key}
      if lease_info != nil
        lease = Bluzelle::lease_info_to_blocks(lease_info)
        if lease < 0
          raise APIError.new(INVALID_LEASE_TIME)
        end
        payload["Lease"] = lease.to_s
      end
      payload["Value"] = value
      send_transaction(
        'post',
        '/crud/create',
        payload,
        gas_info
      )
    end

    def update(key, value, gas_info, lease_info = nil)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      if !value.instance_of? String
        raise APIError.new(VALUE_MUST_BE_A_STRING)
      end
      payload = {"Key" => key}
      if lease_info != nil
        lease = Bluzelle::lease_info_to_blocks(lease_info)
        if lease < 0
          raise APIError.new(INVALID_LEASE_TIME)
        end
        payload["Lease"] = lease.to_s
      end
      payload["Value"] = value
      send_transaction(
        "post",
        "/crud/update",
        payload,
        gas_info
      )
    end

    def delete(key, gas_info)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      send_transaction(
        "delete",
        "/crud/delete",
        {"Key" => key},
        gas_info
      )
    end

    def rename(key, new_key, gas_info)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      if !new_key.instance_of? String
        raise APIError.new(NEW_KEY_MUST_BE_A_STRING)
      end
      send_transaction(
        "post",
        "/crud/rename",
        {"Key" => key, "NewKey" => new_key},
        gas_info
      )
    end

    def delete_all(gas_info)
      send_transaction(
        "post",
        "/crud/deleteall",
        {},
        gas_info
      )
    end

    def multi_update(payload, gas_info)
      send_transaction(
        "post",
        "/crud/multiupdate", {"KeyValues" => payload},
        gas_info
      )
    end

    def renew_lease(key, gas_info, lease_info = nil)
      payload = {"Key" => key}
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      if lease_info != nil
        lease = Bluzelle::lease_info_to_blocks(lease_info)
        if lease < 0
          raise APIError.new(INVALID_LEASE_TIME)
        end
        payload["Lease"] = lease.to_s
      end
      send_transaction(
        "post", "/crud/renewlease",
        payload,
        gas_info
      )
    end

    def renew_lease_all(gas_info, lease_info = nil)
      payload = {}
      if lease_info != nil
        lease = Bluzelle::lease_info_to_blocks(lease_info)
        if lease < 0
          raise APIError.new(INVALID_LEASE_TIME)
        end
        payload["Lease"] = lease.to_s
      end
      send_transaction(
        "post", "/crud/renewleaseall",
        payload,
        gas_info
      )
    end

    def renew_all_leases(gas_info, lease_info = nil)
      renew_lease_all gas_info, lease_info
    end

    # query

    def read(key, proof = nil)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      key = Bluzelle::encode_safe key
      if proof
        url = "/crud/pread/#{@options["uuid"]}/#{key}"
      else
        url = "/crud/read/#{@options["uuid"]}/#{key}"
      end
      api_query(url)["result"]["value"]
    end

    def has(key)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      key = Bluzelle::encode_safe key
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

    def get_lease(key)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      key = Bluzelle::encode_safe key
      url = "/crud/getlease/#{@options["uuid"]}/#{key}"
      Bluzelle::lease_blocks_to_seconds api_query(url)["result"]["lease"].to_i
    end

    def get_n_shortest_leases(n)
      if n < 0
        raise APIError.new(INVALID_VALUE_SPECIFIED)
      end
      url = "/crud/getnshortestleases/#{@options["uuid"]}/#{n}"
      kls = api_query(url)["result"]["keyleases"]
      kls.each do |kl|
        kl["lease"] = Bluzelle::lease_blocks_to_seconds kl["lease"].to_i
      end
      kls
    end

    #

    def tx_read(key, gas_info)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      res = send_transaction("post", "/crud/read", {"Key" => key}, gas_info)
      res["value"]
    end

    def tx_has(key, gas_info)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      res = send_transaction("post", "/crud/has", {"Key" => key}, gas_info)
      res["has"]
    end

    def tx_count(gas_info)
      res = send_transaction("post", "/crud/count", {}, gas_info)
      res["count"].to_i
    end

    def tx_keys(gas_info)
      res = send_transaction("post", "/crud/keys", {}, gas_info)
      res["keys"]
    end

    def tx_key_values(gas_info)
      res = send_transaction("post", "/crud/keyvalues", {}, gas_info)
      res["keyvalues"]
    end

    def tx_get_lease(key, gas_info)
      if !key.instance_of? String
        raise APIError.new(KEY_MUST_BE_A_STRING)
      end
      res = send_transaction("post", "/crud/getlease", {"Key" => key}, gas_info)
      Bluzelle::lease_blocks_to_seconds res["lease"].to_i
    end

    def tx_get_n_shortest_leases(n, gas_info)
      if n < 0
        raise APIError.new(INVALID_VALUE_SPECIFIED)
      end
      res = send_transaction("post", "/crud/getnshortestleases", {"N" => n.to_s}, gas_info)
      kls = res["keyleases"]
      kls.each do |kl|
        kl["lease"] = Bluzelle::lease_blocks_to_seconds kl["lease"].to_i
      end
      kls
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

    def send_transaction(method, endpoint, payload, gas_info)
      @broadcast_retries = 0
      txn = validate_transaction(method, endpoint, payload)
      broadcast_transaction(txn, gas_info)
    end

    def validate_transaction(method, endpoint, payload)
      payload = payload.merge({
        'BaseReq' => {
          'chain_id' => @options['chain_id'],
          'from' => @address
        },
        'Owner' => @address,
        'UUID' => @options['uuid']
      })
      api_mutate(method, endpoint, payload)['value']
    end

    def broadcast_transaction(data, gas_info)
      # fee
      Bluzelle::validate_gas_info gas_info

      fee = data['fee']
      gas = fee['gas'].to_i
      amount = 0
      if fee.fetch('amount', []).size() > 0
        amount = fee['amount'][0]['amount'].to_i
      end

      max_gas = gas_info.fetch('max_gas', nil)
      max_fee = gas_info.fetch('max_fee', nil)
      gas_price = gas_info.fetch('gas_price', nil)

      if max_gas != 0 && gas > max_gas
        gas = max_gas
      end
      if max_fee != 0
        amount = max_fee
      elsif gas_price != 0
        amount = gas * gas_price
      end

      # sort
      txn = build_txn(
        {"gas" => gas.to_s, "amount" => [{ 'denom' => TOKEN_NAME, 'amount' => amount.to_s}]},
        data['msg'][0]
      )

      # signatures
      txn['signatures'] = [{
        'account_number' => @bluzelle_account['account_number'].to_s,
        'pub_key' => {
          'type' => PUB_KEY_TYPE,
          'value' => Bluzelle::base64_encode(@wallet.public_key.compressed.to_bytes)
        },
        'sequence' => @bluzelle_account['sequence'].to_s,
        'signature' => sign_transaction(txn)
      }]

      payload = { 'mode' => 'block', 'tx' => txn }
      response = api_mutate('post', TX_COMMAND, payload)

      # https://github.com/bluzelle/blzjs/blob/45fe51f6364439fa88421987b833102cc9bcd7c0/src/swarmClient/cosmos.js#L240-L246
      # note - as of right now (3/6/20) the responses returned by the Cosmos REST interface now look like this:
      # success case: {"height":"0","txhash":"3F596D7E83D514A103792C930D9B4ED8DCF03B4C8FD93873AB22F0A707D88A9F","raw_log":"[]"}
      # failure case: {"height":"0","txhash":"DEE236DEF1F3D0A92CB7EE8E442D1CE457EE8DB8E665BAC1358E6E107D5316AA","code":4,
      #  "raw_log":"unauthorized: signature verification failed; verify correct account sequence and chain-id"}
      #
      # this is far from ideal, doesn't match their docs, and is probably going to change (again) in the future.
      unless response.fetch('code', nil)
        @bluzelle_account['sequence'] += 1
        if response.fetch('data', nil)
          return JSON.parse Bluzelle::hex_to_ascii response['data']
        end
        return
      end

      raw_log = response["raw_log"]
      if raw_log.include?("signature verification failed")
        @broadcast_retries += 1
        @logger.warn("transaction failed ... retrying(#{@broadcast_retries}) ...")
        if @broadcast_retries >= BROADCAST_MAX_RETRIES
          raise APIError.new("transaction failed after max retry attempts", response)
        end

        sleep BROADCAST_RETRY_INTERVAL_SECONDS
        set_account()
        broadcast_transaction(txn, gas_info)
        return
      end

      raise APIError.new(raw_log, response)
    end

    def sign_transaction(txn)
      payload = {
        'account_number' => @bluzelle_account['account_number'].to_s,
        'chain_id' => @options['chain_id'],
        'fee' => txn['fee'],
        'memo' => txn['memo'],
        'msgs' => txn['msg'],
        'sequence' => @bluzelle_account['sequence'].to_s
      }
      payload = Bluzelle::json_dumps payload
      payload = Bluzelle::sanitize_string payload
      pk = Secp256k1::PrivateKey.new(privkey: @wallet.private_key.to_bytes, raw: true)
      rs = pk.ecdsa_sign payload
      r = rs.slice(0, 32).read_string.reverse
      s = rs.slice(32, 32).read_string.reverse
      sig = "#{r}#{s}"
      Bluzelle::base64_encode sig
    end

    def build_txn(fee, msg)
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
      sorted_msg_value = {}
      MSG_KEYS_ORDER.each do |key|
        val = msg_value.fetch(key, nil)
        sorted_msg_value[key] = val if val
      end
      txn['msg'] = [
        {
          "type" => msg['type'],
          "value" => sorted_msg_value
        }
      ]
      txn
    end

    def get_response_error(response)
      error = response['error']
      return APIError.new(error, response) if error
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

  def self.hex_to_ascii(h)
    [h].pack('H*')
  end

  def self.make_random_string(size)
    SecureRandom.alphanumeric size
  end

  def self.json_dumps(h)
    JSON.dump h
    # h.to_json
    # Hash[*h.sort.flatten].to_json
  end

  def self.lease_info_to_blocks(lease_info)
    if !lease_info
      raise OptionsError, 'provided lease info is nil'
    end
    unless lease_info.class.equal?(Hash)
      raise OptionsError, 'lease_info should be a hash of {days, hours, minutes, seconds}'
    end

    days = lease_info.fetch('days', 0)
    hours = lease_info.fetch('hours', 0)
    minutes = lease_info.fetch('minutes', 0)
    seconds = lease_info.fetch('seconds', 0)

    if seconds
      unless seconds.class.equal?(Integer)
        raise OptionsError, 'lease_info[seconds] should be an int'
      end
    end
    if minutes
      unless minutes.class.equal?(Integer)
        raise OptionsError, 'lease_info[minutes] should be an int'
      end
    end
    if hours
      unless hours.class.equal?(Integer)
        raise OptionsError, 'lease_info[hours] should be an int'
      end
    end
    if days
      unless days.class.equal?(Integer)
        raise OptionsError, 'lease_info[days] should be an int'
      end
    end

    seconds += days * 24 * 60 * 60
  	seconds += hours * 60 * 60
  	seconds += minutes * 60
    seconds / BLOCK_TIME_IN_SECONDS # rounded down
  end

  def self.lease_blocks_to_seconds(blocks)
    blocks * BLOCK_TIME_IN_SECONDS
  end

  def self.validate_gas_info gas_info
    if gas_info == nil
      raise OptionsError, "gas_info is required"
    end
    unless gas_info.class.equal?(Hash)
      raise OptionsError, 'gas_info should be a hash of {gas_price, max_fee, max_gas}'
    end

    gas_info_keys = %w[gas_price max_fee max_gas]
    gas_info_keys.each do |k|
      v = gas_info.fetch(k, 0)
      unless v.class.equal?(Integer)
        raise OptionsError, "gas_info[#{k}] should be an int"
      end

      gas_info[k] = v
    end
    gas_info
  end

  def self.sanitize_string(s)
    s.gsub(/([&<>])/) { |token|
      "\\u00#{token[0].ord.to_s(16)}"
    }
  end

  def self.encode_safe(s)
    a = URI.escape(s)
    b = a.gsub(/[\[\]\#\?]/) { |token| "%#{token[0].ord.to_s(16)}" }
    b
  end
end
