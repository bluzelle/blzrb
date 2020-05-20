describe "options" do
  it "requires mnemonic", :type => :feature do
    expect { Bluzelle::new_client({
    }) }.to raise_error(Bluzelle::OptionsError, "mnemonic is required")

    expect { Bluzelle::new_client({
      "mnemonic" => 1
    }) }.to raise_error(Bluzelle::OptionsError, "mnemonic must be a string")
  end

  it "requires uuid", :type => :feature do
    expect { Bluzelle::new_client({
      "mnemonic" => "...",
    }) }.to raise_error(Bluzelle::OptionsError, "uuid is required")

    expect { Bluzelle::new_client({
      "mnemonic" => "...",
      "uuid" => 1,
    }) }.to raise_error(Bluzelle::OptionsError, "uuid must be a string")
  end

  it "validates gas info", :type => :feature do
    expect { Bluzelle::validate_gas_info "" }.to raise_error(Bluzelle::OptionsError, "gas_info should be a hash of {gas_price, max_fee, max_gas}")
    expect { Bluzelle::validate_gas_info 1 }.to raise_error(Bluzelle::OptionsError, "gas_info should be a hash of {gas_price, max_fee, max_gas}")
    expect { Bluzelle::validate_gas_info [] }.to raise_error(Bluzelle::OptionsError, "gas_info should be a hash of {gas_price, max_fee, max_gas}")
    expect { Bluzelle::validate_gas_info({ "gas_price" => "" }) }.to raise_error(Bluzelle::OptionsError, "gas_info[gas_price] should be an int")
  end

  it "correctly derives address", :type => :feature do
    c = new_client
    expect(c.address).to eq(ADDRESS)
  end
end

describe "lease" do
  it "converts blocks to seconds", :type => :feature do
    expect(Bluzelle::lease_blocks_to_seconds(1)).to eq(5)
    expect(Bluzelle::lease_blocks_to_seconds(2)).to eq(10)
    expect(Bluzelle::lease_blocks_to_seconds(3)).to eq(15)
  end
  it "converts lease_info to blocks", :type => :feature do
    expect(Bluzelle::lease_info_to_blocks({
    })).to eq(0)
    expect(Bluzelle::lease_info_to_blocks({
      "seconds" => 5
    })).to eq(1)
    expect(Bluzelle::lease_info_to_blocks({
      "seconds" => 5,
      "minutes" => 1,
    })).to eq(13)
    expect(Bluzelle::lease_info_to_blocks({
      "seconds" => 5,
      "minutes" => 1,
      "hours" => 1,
    })).to eq(733)
    expect(Bluzelle::lease_info_to_blocks({
      "seconds" => 5,
      "minutes" => 1,
      "hours" => 1,
      "days" => 1,
    })).to eq(18013)
  end
end
