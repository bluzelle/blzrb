Gem::Specification.new do |spec|
  spec.name        = 'bluzelle'
  spec.version     = '0.1.1'
  spec.date        = '2020-04-20'
  spec.summary     = "Ruby gem client library for the Bluzelle Service"
  spec.description = "Ruby gem client library for the Bluzelle Service"
  spec.authors     = ["bluzelle"]
  spec.email       = 'hello@bluzelle.com'
  spec.files       = ["lib/bluzelle.rb"]
  spec.homepage    = 'https://rubygemspec.org/gems/bluzelle'
  spec.license     = 'MIT'

#   spec.add_dependency "money-tree"
#   spec.add_dependency "secp256k1"
  spec.add_dependency "ecdsa", "~> 1.2.0"
  spec.add_dependency "bip_mnemonic", "~> 0.0.4"

  spec.add_development_dependency "dotenv"
end
