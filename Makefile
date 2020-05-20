o?=$(o)

example:
	@LIBRESSL_REDIRECT_STUB_ABORT=0 bundle exec ruby examples/crud.rb

test:
	@bundle exec rspec --format documentation --fail-fast $(o)

test-all:
	@bundle exec rspec --format documentation --fail-fast

deploy:
	@rm -f *.gem
	@gem build bluzelle.gemspec
	@gem push *.gem
	@rm -f *.gem

uat:
	@bundle exec ruby uat/server.rb

.PHONY: example \
	test \
	test-all \
	deploy \
	uat
