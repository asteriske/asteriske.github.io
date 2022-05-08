install:
	rbenv local 3.1.2
	gem install bundler webrick
	bundle install
run:
	bundle exec jekyll serve
