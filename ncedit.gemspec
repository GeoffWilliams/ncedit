# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ncedit/version'

Gem::Specification.new do |spec|
  spec.name          = "ncedit"
  spec.version       = NCEdit::VERSION
  spec.authors       = ["Declarative Systems"]
  spec.email         = ["sales@declarativesystems.com"]
  spec.license       = "Apache-2.0"

  spec.summary       = %q{Edit Puppet Enterprise Node Classifier rules}
  spec.description   = %q{Use the puppet-classify gem to create/edit NC rules}
  spec.homepage      = "https://github.com/declarativesystems/ncedit"


  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_runtime_dependency "escort", "0.4.0"
  spec.add_runtime_dependency "json_pure", "2.1.0"
  spec.add_runtime_dependency "puppetclassify", "0.1.8"
end
