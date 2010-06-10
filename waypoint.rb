#!/usr/bin/env ruby
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
