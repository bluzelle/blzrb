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

    @client = new_client

    example.run
  end

  #

  it "reads account", :type => :feature do
    account = @client.read_account()
    expect(account['address']).to eq(ADDRESS)
  end

  it "reads version", :type => :feature do
    version = @client.version()
    expect(version).to_not be_nil
  end

  #

  it "creates key", :type => :feature do
    @client.create @key1, @value1
  end

  it "creates key with lease info", :type => :feature do
    @client.create @key1, @value1, lease_info: {
      "seconds" => 60
    }
  end

  it "creates key with custom gas info", :type => :feature do
    @client.create @key1, @value1, gas_info: {
      "max_fee" => 1000000000
    }
    expect { @client.create @key2, @value1, gas_info: {
      "max_fee" => 1
    } }.to raise_error(Bluzelle::APIError, "insufficient fee: insufficient fees; got: 1ubnt required: 2000000ubnt")
  end

  it "updates key", :type => :feature do
    @client.create(@key1, @value1)
    @client.update(@key1, @value2)
    value = @client.read(@key1)
    expect(value).to eq(@value2)
    expect(value).to_not eq(@value1)
  end

  it "deletes key", :type => :feature do
    @client.create(@key1, @value1)
    @client.delete(@key1)
    expect { @client.read(@key1) }.to raise_error(Bluzelle::APIError, "unknown request: key not found")
  end

  it "renames key", :type => :feature do
    @client.create(@key1, @value1)
    @client.rename(@key1, @key2)
    value = @client.read(@key2)
    expect(value).to eq(@value1)
    expect { @client.read(@key1) }.to raise_error(Bluzelle::APIError, "unknown request: key not found")
  end

  it "deletes all keys in uuid", :type => :feature do
    @client.create(@key1, @value1)
    @client.create(@key2, @value1)
    @client.read(@key1)
    @client.read(@key1)
    @client.delete_all()
    num = @client.count()
    expect(num).to eq(0)
  end

  it "multi updates keys", :type => :feature do
    @client.create(@key1, @value1)
    @client.create(@key2, @value1)
    #
    data = {}
    data[@key1] = @key1
    data[@key2] = @key2
    @client.multi_update(data)
    #
    expect(@client.read(@key1)).to eq(@key1)
    expect(@client.read(@key2)).to eq(@key2)
  end

  it "renews key lease", :type => :feature do
    @client.create(@key1, @value1, lease_info: @lease1)
    @client.renew_lease(@key1, @lease2)
    lease = @client.get_lease(@key1)
    expect(lease).to be > @lease1["seconds"]
  end

  it "renews all key leases in uuid", :type => :feature do
    @client.create(@key1, @value1, lease_info: @lease1)
    @client.renew_all_leases(@lease2)
    lease = @client.get_lease(@key1)
    expect(lease).to be > @lease1["seconds"]
  end

  #

  it "reads key", :type => :feature do
    @client.create @key1, @value1
    value = @client.read @key1
    expect(value).to eq(@value1)
  end

  it "checks has key", :type => :feature do
    @client.create(@key1, @value1)
    b = @client.has(@key1)
    expect(b).to be_truthy
  end

  it "counts keys in uuid", :type => :feature do
    num = @client.count()
    @client.create(@key1, @value1)
    num2 = @client.count()
    expect(num+1).to eq(num2)
  end

  it "reads keys in uuid", :type => :feature do
    keys = @client.keys()
    expect(keys).to_not include(@key1)
    @client.create(@key1, @value1)
    keys = @client.keys()
    expect(keys).to include(@key1)
  end

  it "reads keyvalues in uuid", :type => :feature do
    key_values = key_values_to_dict(@client.key_values())
    expect(key_values).to_not have_key(@key1)
    @client.create(@key1, @value1)
    key_values = key_values_to_dict(@client.key_values())
    expect(key_values[@key1]).to eq(@value1)
  end

  it "reads key lease", :type => :feature do
    @client.create(@key1, @value1, lease_info: @lease1)
    lease = @client.get_lease(@key1)
    expect(lease).to be <= @lease1["seconds"]
  end

  it "reads n shortest key leases", :type => :feature do
    @client.create(@key1, @value1, lease_info: @lease1)
    @client.create(@key2, @value1, lease_info: @lease1)
    @client.create(@key3, @value1, lease_info: @lease1)
    keyleases = @client.get_n_shortest_leases(2)
    expect(keyleases.size).to eq(2)
  end

  #

  it "tx reads key", :type => :feature do
    @client.create @key1, @value1
    value = @client.tx_read @key1
    expect(value).to eq(@value1)
  end

  it "tx checks has key", :type => :feature do
    @client.create(@key1, @value1)
    b = @client.tx_has(@key1)
    expect(b).to be_truthy
  end

  it "tx counts keys in uuid", :type => :feature do
    num = @client.count()
    @client.create(@key1, @value1)
    num2 = @client.tx_count()
    expect(num+1).to eq(num2)
  end

  it "tx reads keys in uuid", :type => :feature do
    keys = @client.tx_keys()
    expect(keys).to_not include(@key1)
    @client.create(@key1, @value1)
    keys = @client.tx_keys()
    expect(keys).to include(@key1)
  end

  it "tx reads keyvalues in uuid", :type => :feature do
    key_values = key_values_to_dict(@client.tx_key_values())
    expect(key_values).to_not have_key(@key1)
    @client.create(@key1, @value1)
    key_values = key_values_to_dict(@client.tx_key_values())
    expect(key_values[@key1]).to eq(@value1)
  end

  it "tx reads key lease", :type => :feature do
    @client.create(@key1, @value1, lease_info: @lease1)
    lease = @client.tx_get_lease(@key1)
    expect(lease).to be <= @lease1["seconds"]
  end

  it "tx reads n shortest key leases", :type => :feature do
    @client.create(@key1, @value1, lease_info: @lease1)
    @client.create(@key2, @value1, lease_info: @lease1)
    @client.create(@key3, @value1, lease_info: @lease1)
    keyleases = @client.tx_get_n_shortest_leases(2)
    expect(keyleases.size).to eq(2)
  end
end
