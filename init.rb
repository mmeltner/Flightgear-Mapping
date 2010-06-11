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

Dir.chdir(File.dirname(__FILE__))

load "waypoint.rb"

