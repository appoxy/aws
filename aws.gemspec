
require File.expand_path('../lib/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Travis Reeder", "Chad Arimura", "RightScale"]
  gem.email         = ["travis@appoxy.com"]
  gem.description   = "AWS Ruby Library for interfacing with Amazon Web Services including EC2, S3, SQS, SimpleDB and most of their other services as well. By http://www.appoxy.com"
  gem.summary       = "AWS Ruby Library for interfacing with Amazon Web Services including EC2, S3, SQS, SimpleDB and most of their other services as well. By http://www.appoxy.com"
  gem.homepage      = "http://github.com/appoxy/aws/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "aws"
  gem.require_paths = ["lib"]
  gem.version       = Aws::VERSION

  gem.required_rubygems_version = ">= 1.3.6"
  gem.required_ruby_version = Gem::Requirement.new(">= 1.8")
  gem.add_runtime_dependency "uuidtools", ">= 0"
  gem.add_runtime_dependency "xml-simple", ">= 0"
  gem.add_runtime_dependency "http_connection", ">= 0"

end

