require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

exclude_me = ['*.ui', '*.png', '*.svg', '*.qrc', 'Makefile', 'compress-resource.rb']

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "fgmapping"
  gem.homepage = "http://rubyforge.org/frs/?group_id=9572"
  gem.license = "GPL2"
  gem.summary = %Q{Real-time mapping for Flightgear}
  gem.description = %Q{Provide a real-time map of flight position in Flightgear. It is based on tiles from Openstreetmap with elevation shading, provides navigation aids and runways, allows setting of waypoints, sends these to Flightgear's route-manager and tracks the flight.}
  gem.email = "mmeltner@gmail.com"
  gem.authors = ["Michael Meltner"]
  gem.rubyforge_project = "fgmap"
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
#  gem.add_runtime_dependency 'qtbindings', '>= 4.6.3.1'

  exclude_me.each do |excl|
    gem.files.exclude "lib/**/#{excl}"
  end
end
Jeweler::GemcutterTasks.new
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "fgmap #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
