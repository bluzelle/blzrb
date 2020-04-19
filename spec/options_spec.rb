describe "methods" do
  it "requires address", :type => :feature do
    expect { Bluzelle::new_client({}) }.to raise_error(Bluzelle::OptionsError, "address is required")
  end

  it "requires mnemonic", :type => :feature do
    expect { Bluzelle::new_client({
      "address" => "1"
    }) }.to raise_error(Bluzelle::OptionsError, "mnemonic is required")
  end

  it "validates gas info", :type => :feature do
    expect { Bluzelle::new_client({
      "address" => "1",
      "mnemonic" => "1",
      "gas_info" => ""
    }) }.to raise_error(Bluzelle::OptionsError, "gas_info should be a dict of {gas_price, max_fee, max_gas}")

    expect { Bluzelle::new_client({
      "address" => "1",
      "mnemonic" => "1",
      "gas_info" => 1
    }) }.to raise_error(Bluzelle::OptionsError, "gas_info should be a dict of {gas_price, max_fee, max_gas}")

    expect { Bluzelle::new_client({
      "address" => "1",
      "mnemonic" => "1",
      "gas_info" => []
    }) }.to raise_error(Bluzelle::OptionsError, "gas_info should be a dict of {gas_price, max_fee, max_gas}")

    expect { Bluzelle::new_client({
      "address" => "1",
      "mnemonic" => "1",
      "gas_info" => {
          "gas_price" => ""
      }
    }) }.to raise_error(Bluzelle::OptionsError, "gas_info[gas_price] should be an int")
  end

  it "validates mnemonic and address", :type => :feature do
    expect { Bluzelle::new_client({
      "address" => "1",
      "mnemonic" => MNEMONIC
    }) }.to raise_error(Bluzelle::OptionsError, "bad credentials(verify your address and mnemonic)")
  end
end