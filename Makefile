o = $(o)

example:
	@LIBRESSL_REDIRECT_STUB_ABORT=0 bundle exec ruby example/crud.rb

test:
	@bundle exec rspec --format documentation $(o)

deploy:
	@gem build bluzelle.gemspec
	@gem push *.gem
	@rm -f *.gem

.PHONY: example \
	test \
	deploy
