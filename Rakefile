# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "standard/rake"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

namespace :rbs do
  desc "Clean generated RBS files"
  task :clean do
    rm_rf "sig/generated"
  end

  desc "Generate RBS files from rbs-inline annotations"
  task :generate do
    sh "bundle exec rbs-inline --opt-out --output sig lib/"
  end

  desc "Validate generated RBS files"
  task :validate do
    sh "bundle exec rbs -I sig validate"
  end

  desc "Run Steep type check"
  task :steep do
    sh "bundle exec steep check"
  end

  desc "Setup RBS collection"
  task :setup do
    sh "bundle exec rbs collection install"
  end
end

desc "Generate RBS and run type check"
task rbs: %w[rbs:generate rbs:steep]

task default: %i[standard rbs test]
