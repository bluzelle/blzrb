o?=$(o)

example:
	@LIBRESSL_REDIRECT_STUB_ABORT=0 bundle exec ruby examples/crud.rb

test:
	@bundle exec rspec --format documentation --fail-fast $(o)

deploy:
	@rm -f *.gem
	@gem build bluzelle.gemspec
	@gem push *.gem
	@rm -f *.gem

uat:
	@bundle exec ruby uat/server.rb

.PHONY: example \
	test \
	deploy \
	uat
