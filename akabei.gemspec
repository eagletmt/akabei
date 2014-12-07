# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'akabei/version'

Gem::Specification.new do |spec|
  spec.name          = "akabei"
  spec.version       = Akabei::VERSION
  spec.authors       = ["Kohei Suzuki"]
  spec.email         = ["eagletmt@gmail.com"]
  spec.summary       = %q{Custom repository manager for ArchLinux pacman}
  spec.description   = %q{Custom repository manager for ArchLinux pacman}
  spec.homepage      = "https://github.com/eagletmt/akabei"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "gpgme"
  spec.add_dependency "libarchive"
  spec.add_dependency "safe_yaml"
  spec.add_dependency "thor"
  spec.add_development_dependency "aws-sdk-core"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", ">= 3.0"
  spec.add_development_dependency "simplecov"
end
