describe "methods" do
  around :each do |example|
    now = Time.now.to_i
    @key1 = "#{now}"
    @key2 = "#{now + 1000}"
    @key3 = "#{now + 2000}"
    @value1 = 'foo'
    @value2 = 'bar'
    @value3 = 'baz'
    @lease1 = 10
    @lease2 = 20

    @client = new_client

    example.run
  end

  it "creates key", :type => :feature do
    @client.create @key1, @value1
  end

  it "reads key", :type => :feature do
    @client.create @key1, @value1
    value = @client.read @key1
    expect(value).to eq(@value1)
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

  it "reads account", :type => :feature do
    account = @client.read_account()
    expect(account['address']).to eq(ADDRESS)
  end
end
