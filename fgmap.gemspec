# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{fgmap}
  s.version = "2.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Michael Meltner"]
  s.date = %q{2010-11-23}
  s.default_executable = %q{fgmap}
  s.description = %q{Provide a real-time map of flight position in Flightgear. It is based on tiles from Openstreetmap with elevation shading, provides navigation aids and runways, allows setting of waypoints, sends these to Flightgear's route-manager and tracks the flight.}
  s.email = %q{mmeltner@gmail.com}
  s.executables = ["fgmap"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README",
    "README.rdoc"
  ]
  s.files = [
    "LICENSE.txt",
    "README",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/fgmap",
    "fgmap.gemspec",
    "lib/fgmap.rb",
    "lib/fgmap/bsearch.rb",
    "lib/fgmap/context_menu.rb",
    "lib/fgmap/hud-impl.rb",
    "lib/fgmap/hud-widget.rb",
    "lib/fgmap/main-dlg-impl.rb",
    "lib/fgmap/main-dlg.rb",
    "lib/fgmap/navaid.rb",
    "lib/fgmap/nodeinfo-impl.rb",
    "lib/fgmap/nodeinfo-widget.rb",
    "lib/fgmap/resources.marshal",
    "lib/fgmap/resources.rb",
    "lib/fgmap/tile.rb",
    "lib/fgmap/waypoint.rb",
    "test/helper.rb",
    "test/test_fgmap.rb"
  ]
  s.homepage = %q{http://rubyforge.org/frs/?group_id=9572}
  s.licenses = ["GPL2"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{fgmap}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Real-time mapping for Flightgear}
  s.test_files = [
    "test/helper.rb",
    "test/test_fgmap.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.5.1"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
    else
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.5.1"])
      s.add_dependency(%q<rcov>, [">= 0"])
    end
  else
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.5.1"])
    s.add_dependency(%q<rcov>, [">= 0"])
  end
end

