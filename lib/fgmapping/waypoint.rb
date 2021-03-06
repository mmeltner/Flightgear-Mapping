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

require "rubygems"
require "Qt4"
require "./main-dlg-impl.rb"

enc = __ENCODING__.names[0]
p enc

# important settings so that ruby and QT4 are in sync regarding its locale
Qt::TextCodec.setCodecForTr(Qt::TextCodec.codecForName(enc)); 
Qt::TextCodec.setCodecForLocale(Qt::TextCodec.codecForName(enc)); 
Qt::TextCodec.setCodecForCStrings(Qt::TextCodec.codecForName(enc)); 

a = Qt::Application.new(ARGV)
a.setWindowIcon(Qt::Icon.new(":/icons/vor.png"))
u = Qt::MainWindow.new

w = MainDlg.new(u, ARGV[0])
u.resize(w.size) # set Mainwindow to correct size
u.setCentralWidget(w) # make widget part of the mainwindow to allow resizing
u.show
w.movemap(w.node,true)

a.exec
