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

  it "creates", :type => :feature do
    @client.create @key1, @value1
  end

  it "reads", :type => :feature do
    @client.create @key1, @value1
    value = @client.read @key1
    expect(value).to eq(@value1)
  end

  it "updates", :type => :feature do
    @client.create(@key1, @value1)
    @client.update(@key1, @value2)
    value = @client.read(@key1)
    expect(value).to eq(@value2)
    expect(value).to_not eq(@value1)
  end

  it "deletes", :type => :feature do
    @client.create(@key1, @value1)
    @client.delete(@key1)
    expect { @client.read(@key1) }.to raise_error(Bluzelle::APIError, "unknown request: key not found")
  end

  it "renames", :type => :feature do
    @client.create(@key1, @value1)
    @client.rename(@key1, @key2)
    value = @client.read(@key2)
    expect(value).to eq(@value1)
    expect { @client.read(@key1) }.to raise_error(Bluzelle::APIError, "unknown request: key not found")
  end

  it "has", :type => :feature do
    @client.create(@key1, @value1)
    b = @client.has(@key1)
    expect(b).to be_truthy
  end

  it "counts", :type => :feature do
    num = @client.count()
    @client.create(@key1, @value1)
    num2 = @client.count()
    expect(num+1).to eq(num2)
  end
end
