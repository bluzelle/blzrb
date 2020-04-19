o = $(o)

example:
	@LIBRESSL_REDIRECT_STUB_ABORT=0 bundle exec ruby example/crud.rb

test:
	@bundle exec rspec --format documentation $(o)

.PHONY: example \
	test
