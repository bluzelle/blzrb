![](https://raw.githubusercontent.com/bluzelle/api/master/source/images/Bluzelle%20-%20Logo%20-%20Big%20-%20Colour.png)

### Getting started

Ensure you have a recent version of [Ruby](https://www.ruby-lang.org/en/) installed.

1. Install `libsecp256k1` as described [here](https://github.com/cryptape/ruby-bitcoin-secp256k1#prerequisite).

2. Add the gem to your Gemfile:

```
gem 'money-tree', git: 'https://github.com/bluzelle/money-tree'
gem 'bitcoin-secp256k1', git: 'git@github.com:cryptape/ruby-bitcoin-secp256k1'
gem 'bluzelle', git: 'https://github.com/bluzelle/blzrb'
```

3. Then install:

```
bundle install
```

4. Use:

```ruby
require "bluzelle"

client = Bluzelle::new_client({
  "address" =>  "...",
  "mnemonic" => "...",
  "uuid" => "bluzelle",
  "endpoint" => "http://dev.testnet.public.bluzelle.com:1317",
})

key = 'foo'
gas_info = {
  'max_fee' => 4000001,
}

client.create key, 'bar', gas_info
value = client.read key
client.update key, 'baz', gas_info
client.delete key, gas_info
```

### Examples

Copy `.env.sample` to `.env` and configure if needed.

```
cp .env.sample .env
```

Then run the example:

```
DEBUG=false LIBRESSL_REDIRECT_STUB_ABORT=0 bundle exec ruby examples/crud.rb
```

### Tests

Configure env as described in the examples section above.

```
bundle exec rspec --format documentation
```

### User Acceptance Testing

Please checkout the [UAT.md](https://github.com/bluzelle/blzrb/blob/master/UAT.md) document for more details.

### Abort 6 error

If you encounter this error, you either might have to:

- Add a new entry to [`ffi_lib` in `money-tree/lib/openssl_extensions.rb`](https://github.com/bluzelle/money-tree/blob/244549cbc855b65c4a003ae1b089a0adc793f482/lib/openssl_extensions.rb#L9) if using a newer OpenSSL version
- Specify where your `libsecp256k1.dylib` is located with the [`LIBSECP256K1` environment variable](https://github.com/cryptape/ruby-bitcoin-secp256k1/blob/e2f47bcc9e85b4d52eeaf4f7649a9a25b0083a11/lib/secp256k1/c.rb#L9).

### Licence

MIT
