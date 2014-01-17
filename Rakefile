require "bundler/gem_tasks"

task :default => :spec

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
namespace :spec do
  task :set_arch do
    ENV['AKABEI_ARCH_SPEC'] = '1'
  end

  desc 'Run all RSpec examples including :arch. It requires sudo and devtools package.'
  task :arch => %w[spec:set_arch spec]
end
