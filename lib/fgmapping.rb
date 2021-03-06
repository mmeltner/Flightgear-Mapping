#!/usr/bin/env ruby
##################################################
# Flightgear Mapping
#
# Provide a real-time map of flight position in Flightgear. It is based on tiles from Openstreetmap, 
# downloads them in the background, provides navigation aids and runways, allows setting of waypoints 
# and tracks the flight.
#
# License
# GPL V2
#
# Author Michael Meltner (mmeltner@gmail.com)
##################################################

# check if we were launched via symlink, then resolve it
myself = __FILE__
if File.lstat(myself).symlink? then
	myself = File.readlink(__FILE__)
end
Dir.chdir(File.dirname(myself))

load "./fgmapping/waypoint.rb"

