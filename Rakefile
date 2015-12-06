
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

desc 'Clean up working directory'
task :clean do
  %w(coverage doc .yardoc).each do |f|
    dir = File.join(File.dirname(__FILE__), f)
    FileUtils.remove_entry_secure(dir) if File.directory?(dir)
  end
end

desc 'Generate API docs'
task :yardoc do
  sh 'bundle exec yardoc'
end

desc 'Generate API docs and include test objects'
task :yardoc_dev do
  sh 'bundle exec yardoc --api development'
end

desc 'Execute Rubocop'
task :rubocop do
  sh 'bundle exec rubocop'
end

task :default do
  exec 'rake -T'
end
