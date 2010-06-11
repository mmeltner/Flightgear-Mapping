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
require "rubygems"
require "Qt4"
require "main-dlg-impl.rb"

a = Qt::Application.new(ARGV)
u = Qt::MainWindow.new

w = MainDlg.new(u, ARGV[0])
u.resize(w.size) # set Mainwindow to correct size
u.setCentralWidget(w) # make widget part of the mainwindow to allow resizing
u.show
w.movemap(w.node,true)

a.exec
