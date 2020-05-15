describe "methods" do
  around :each do |example|
    now = Time.now.to_i
    @key1 = "#{now}"
    @key2 = "#{now + 1000}"
    @key3 = "#{now + 2000}"
    @value1 = 'foo'
    @value2 = 'bar'
    @value3 = 'baz'
    @lease1 = {"seconds" => 10}
    @lease2 = {"seconds" => 20}
    @gas_info = {
      'max_fee' => 4_000_001
    }

    @client = new_client

    example.run
  end

  #

  it "reads account", :type => :feature do
    account = @client.account()
    expect(account['address']).to eq(ADDRESS)
  end

  it "reads version", :type => :feature do
    version = @client.version()
    expect(version).to_not be_nil
  end

  #

  it "creates key", :type => :feature do
    @client.create @key1, @value1, @gas_info
  end

  it "creates key with lease info", :type => :feature do
    @client.create @key1, @value1, @gas_info, {
      "seconds" => 60
    }
  end

  it "creates key validates gas info", :type => :feature do
    @client.create @key1, @value1, {
      "max_fee" => 1000000000
    }
    expect { @client.create @key2, @value1, {
      "max_fee" => 1
    } }.to raise_error(Bluzelle::APIError, "insufficient fee: insufficient fees; got: 1ubnt required: 2000000ubnt")
  end

  it "creates key with lease info", :type => :feature do
    k = "#{@key1}#$%&"
    @client.create k, @value1, @gas_info
    keys = @client.keys
    expect(keys).to include(k)
    @client.read k
  end

  it "updates key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    @client.update @key1, @value2, @gas_info
    value = @client.read(@key1)
    expect(value).to eq(@value2)
    expect(value).to_not eq(@value1)
  end

  it "deletes key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    @client.delete @key1, @gas_info
    expect(@client.has(@key1)).to_not be_truthy
  end

  it "renames key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    @client.rename @key1, @key2, @gas_info
    value = @client.read @key2
    expect(value).to eq(@value1)
    expect(@client.has(@key2)).to be_truthy
    expect(@client.has(@key1)).to_not be_truthy
  end

  it "deletes all keys in uuid", :type => :feature do
    @client.create @key1, @value1, @gas_info
    @client.create @key2, @value1, @gas_info
    @client.read @key1
    @client.read @key2
    @client.delete_all(@gas_info)
    num = @client.count()
    expect(num).to eq(0)
  end

  it "multi updates keys", :type => :feature do
    @client.create @key1, @value1, @gas_info
    @client.create @key2, @value1, @gas_info
    #
    data = [
      {"key": @key1, "value": @key1},
      {"key": @key2, "value": @key2}
    ]
    @client.multi_update data, @gas_info
    #
    expect(@client.read(@key1)).to eq(@key1)
    expect(@client.read(@key2)).to eq(@key2)
  end

  it "renews key lease", :type => :feature do
    @client.create @key1, @value1, @gas_info, @lease1
    @client.renew_lease @key1, @gas_info, @lease2
    lease = @client.get_lease @key1
    expect(lease).to be > @lease1["seconds"]
  end

  it "renews all key leases in uuid", :type => :feature do
    @client.create @key1, @value1, @gas_info, @lease1
    @client.renew_all_leases @gas_info, @lease2
    lease = @client.get_lease @key1
    expect(lease).to be > @lease1["seconds"]
  end

  #

  it "reads key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    value = @client.read @key1
    expect(value).to eq(@value1)
  end

  it "checks has key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    b = @client.has @key1
    expect(b).to be_truthy
  end

  it "counts keys in uuid", :type => :feature do
    num = @client.count
    @client.create @key1, @value1, @gas_info
    num2 = @client.count
    expect(num+1).to eq(num2)
  end

  it "reads keys in uuid", :type => :feature do
    keys = @client.keys
    expect(keys).to_not include(@key1)
    @client.create @key1, @value1, @gas_info
    keys = @client.keys
    expect(keys).to include(@key1)
  end

  it "reads keyvalues in uuid", :type => :feature do
    key_values = key_values_to_dict(@client.key_values())
    expect(key_values).to_not have_key(@key1)
    @client.create @key1, @value1, @gas_info
    key_values = key_values_to_dict(@client.key_values())
    expect(key_values[@key1]).to eq(@value1)
  end

  it "reads key lease", :type => :feature do
    @client.create @key1, @value1, @gas_info, @lease1
    lease = @client.get_lease @key1
    expect(lease).to be <= @lease1["seconds"]
  end

  it "reads n shortest key leases", :type => :feature do
    @client.create @key1, @value1, @gas_info, @lease1
    @client.create @key2, @value1, @gas_info, @lease1
    @client.create @key3, @value1, @gas_info, @lease1
    keyleases = @client.get_n_shortest_leases 2
    expect(keyleases.size).to eq(2)
  end

  #

  it "tx reads key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    value = @client.tx_read @key1, @gas_info
    expect(value).to eq(@value1)
  end

  it "tx checks has key", :type => :feature do
    @client.create @key1, @value1, @gas_info
    b = @client.tx_has @key1, @gas_info
    expect(b).to be_truthy
  end

  it "tx counts keys in uuid", :type => :feature do
    num = @client.tx_count @gas_info
    @client.create @key1, @value1, @gas_info
    num2 = @client.tx_count @gas_info
    expect(num+1).to eq(num2)
  end

  it "tx reads keys in uuid", :type => :feature do
    keys = @client.tx_keys @gas_info
    expect(keys).to_not include(@key1)
    @client.create @key1, @value1, @gas_info
    keys = @client.tx_keys @gas_info
    expect(keys).to include(@key1)
  end

  it "tx reads keyvalues in uuid", :type => :feature do
    key_values = key_values_to_dict(@client.tx_key_values(@gas_info))
    expect(key_values).to_not have_key(@key1)
    @client.create @key1, @value1, @gas_info
    key_values = key_values_to_dict(@client.tx_key_values(@gas_info))
    expect(key_values[@key1]).to eq(@value1)
  end

  it "tx reads key lease", :type => :feature do
    @client.create @key1, @value1, @gas_info, @lease1
    lease = @client.tx_get_lease @key1, @gas_info
    expect(lease).to be <= @lease1["seconds"]
  end

  it "tx reads n shortest key leases", :type => :feature do
    @client.create @key1, @value1, @gas_info, @lease1
    @client.create @key2, @value1, @gas_info, @lease1
    @client.create @key3, @value1, @gas_info, @lease1
    keyleases = @client.tx_get_n_shortest_leases 2, @gas_info
    expect(keyleases.size).to eq(2)
  end
end
