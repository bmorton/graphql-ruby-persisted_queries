require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "appraisal"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
  task default: %i[rubocop appraisal]
else
  task default: %i[rubocop spec]
end
