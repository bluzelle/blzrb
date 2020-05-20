### User Acceptance Testing

The following guide describe setting up the project and running an example code and tests in an Ubuntu 18.04 machine. Once ssh'd into the machine:

1. Ensure you have [rvm](https://rvm.io/) installed, which is a ruby version manager:

```
sudo apt install gnupg2 -y
gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
```

2. Install ruby 2.7.0 and activate it:

```
rvm install 2.7.0
rvm use 2.7.0
```

3. Install [bundler](https://bundler.io/), a ruby project dependencies(gems) manager:

```
gem install bundler -v 2.1.4
```

4. Clone the project:

```
git clone https://github.com/vbstreetz/blzrb.git
cd blzrb
```

5. Install all the required dependencies including development related ones:

```
sudo apt install -y libsecp256k1-dev
bundle install
```

These dependencies are specified in the `Gemfile` config.

6. Setup the sample environment variables:

```
cp .env.sample .env
```

The example code and tests will read the bluzelle settings to use from that file i.e. `.env`.

7. Run the example code located at `examples/crud.rb`:

```
make example
```

This example code performs simple CRUD operations against the testnet.

8. The project also ships a complete suite of integration tests for all the methods. To run all the tests simply run:

```
make test-all
```

This will run all the tests in the `test` directory using the same environment settings defined in the `.env` file.
Note that sometimes one or 2 tests fail due to some existing issues with the testnet. A successful run should however result in an output like this:

```
Finished in 5 minutes 19 seconds (files took 0.35147 seconds to load)
34 examples, 0 failures, 0 pending
```
