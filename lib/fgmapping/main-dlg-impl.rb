# coding: utf-8
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


require 'net/http'
require 'socket'
require 'rexml/document'
require './main-dlg'
require './tile'
require './resources'
require './hud-impl'
require './nodeinfo-impl'
require './navaid.rb'
require './context_menu.rb'
begin
	require 'ap'
rescue LoadError
	def ap(*k)
		p k
	end
end

if RUBY_VERSION =~ /^1\.8/ then
	class Net::HTTP
		alias request_get get
	end
end

OFFSET_FLAG_X = 3
OFFSET_FLAG_Y = 21
OFFSET_PIN_X = 1
OFFSET_PIN_Y = 23
OFFSET_FLAG_COUNTER_X = 5
OFFSET_FLAG_COUNTER_Y = -8
ILSSIZE = 140 # in pixel
ILSCONEANGLE = 10 # in degree
ILSTEXTOFFSET = 10 # in pixel

Z_VALUE_TILES = 0
Z_VALUE_TILES_ELEVATION = 1
Z_VALUE_TRACK = 2
Z_VALUE_TRACK_COLORED = 3
Z_VALUE_WAYPOINT = 4
Z_VALUE_NAV = 5
Z_VALUE_ORIGIN = 6
Z_VALUE_ROSE = 7
Z_VALUE_POINTERTOORIGIN = 8
Z_VALUE_POINTER = 9
Z_VALUE_HUD = 10
Z_VALUE_WARNING = 20
SCALE_SVG = 0.3

OPENSTREETMAP_TILE = 0
ELEVATION_TILE = 1

COLORRANGE_DEG = 120.0
COLOROFFSET_DEG = 240.0

MINSPEED = 0.3 # minimum speed required for heading marker to appear, in m/s
FS_READ_INTERVAL = 100 # enter GUI refresh loop every 100ms
LOOPSLEEPINTERVAL = (0.95 * FS_READ_INTERVAL / 1000) # spend 95% of time sleeping to prevent
																	  # threads from starving. Time is in seconds!
TICKSTOSKIP = 20

AUTOSAVE_INTERVAL = 10 * 60 * 1000 # autosave interval for tracks
HOVER_TIMER = 2000 # time until HUD widget disappears
MAXVORSTODISPLAY = 500 # maximum number of nav-aids to display on map
MAXILSTODISPLAY = 200

FS_PORT = 2948

LATSTARTUP = 50.0368400387281
LONSTARTUP = 8.55965957641601

MAPSDIR = ENV['HOME'] + "/.OpenstreetmapTiles"

#Thread.abort_on_exception = true
#GC.disable

class REXML::Element
	def add_text_element(nodename, text)
		e = REXML::Element.new(nodename)
		e.add_text(text)
		self.add_element(e)
	end
end
		
# Class MainDlg ############################################
class MainDlg < Qt::Widget
	attr_reader :node, :scene_tiles, :scene, :toffset_x, :offset_y, :menu, :waypoints, \
		:flag, :zoom, :mytracks, :mytrack_current, :w
	attr_writer :node, :scene_tiles, :offset_x, :offset_y, :waypoints, :mytrack_current, :w
	attr_accessor :metricUnit
	
	slots "pBexit_clicked()", "pBdo_clicked()", "pBplus_clicked()", "pBminus_clicked()", \
		"cBpointorigin_clicked()", "pBrecordTrack_toggled(bool)", "wakeupTimer()", "autosaveTimer()", \
		'cBvor_clicked()', 'cBndb_clicked()', 'cBrw_clicked()', 'cBshadows_clicked()', 'hSopacity_changed(int)'

	def initialize(parent, arg)
		super(parent)
		@w=Ui::MainDlg.new
		@w.setupUi(self)
		@parent=parent

		@cfg=Qt::Settings.new("MMeltnerSoft", "fg_map")
		@metricUnit = @cfg.value("metricUnit",Qt::Variant.new(true)).toBool
		@zoom = @cfg.value("zoom",Qt::Variant.new(13)).toInt
		@lat = @cfg.value("lat",Qt::Variant.new(LATSTARTUP.to_s)).toDouble
		@lon = @cfg.value("lon",Qt::Variant.new(LONSTARTUP.to_s)).toDouble
		@w.cBrw.setChecked(@cfg.value("rwChecked",Qt::Variant.new(false)).toBool)
		@w.cBndb.setChecked(@cfg.value("nbdChecked",Qt::Variant.new(false)).toBool)
		@w.cBvor.setChecked(@cfg.value("vorChecked",Qt::Variant.new(true)).toBool)
		@opacity = @cfg.value("opacity",Qt::Variant.new((1.0).to_s)).toFloat

		@flag=Qt::Pixmap.new(":/icons/flag-blue.png")
		@pin=Qt::Pixmap.new(":/icons/wpttemp-red.png")
		@linepen = Qt::Pen.new
		@linepen.setWidth(5)
		@colors={:index => 0, :selection  => ["Red", "Yellow", "Green"]}
		@graphicsSceneFont = Qt::Font.new("Helvetica", 7)
		@graphicsSceneBrush = Qt::Brush.new(Qt::Color.new(255, 255, 255, 150))
		@ilsBrush = Qt::Brush.new(Qt::Color.new(0, 0, 0, 150))
		@noPen = Qt::Pen.new(Qt::NoPen)

		@wakeupTimer = Qt::Timer.new( self )
		Qt::Object.connect( @wakeupTimer, SIGNAL('timeout()'), self, SLOT('wakeupTimer()') )
		@wakeupTimer.start( FS_READ_INTERVAL )
		@wakeupCounter = 0
		@autosaveTimer = Qt::Timer.new( self )
		Qt::Object.connect( @autosaveTimer, SIGNAL('timeout()'), self, SLOT('autosaveTimer()') )
		@autosaveTimer.start( AUTOSAVE_INTERVAL )

		@offset_x=@offset_y=0
		@fs_ans=[]
		@fs_queries=["/position/latitude-deg", "/position/longitude-deg", "/position/altitude-ft", 
			"/orientation/heading-deg", "/velocities/groundspeed-kt"]
		@speed = 0

		@waypoints=Way.new(nil,'user', Time.now, "Blue")
		@mytracks=[]
		@mytrack_current=-1
		@prev_track_node = nil
		@posnode = Node.new(1, Time.now, @lon, @lat)
		@tempposnode = Node.new(1, Time.now, @lon, @lat)

		@node = Node.new(1, Time.now, @lon, @lat, 0, @zoom)
		@rot = 0
		@remainingTiles = 0
		@httpThreads = Array.new
		@currentlyDownloading = Array.new
		@currentlyDownloadingElevation = Array.new
		@tilesToAdd = Array.new
		
		@navs = Navaid.new(arg)
		
		@httpMutex = Mutex.new
		@httpElevationMutex = Mutex.new
		@queryMutex = Mutex.new
		@tilesToAddMutex = Mutex.new
		
		@scene=Qt::GraphicsScene.new()
		@w.gVmap.setScene(@scene)
		resetScene()
		
		@w.lBzoom.setText(@zoom.to_s)
		vorGraphic=Qt::GraphicsSvgItem.new(":/icons/vor.svg")
		vorGraphic.setElementId("VOR")
		boundingrect = vorGraphic.boundingRect
		@vor_offsetx = boundingrect.right / 2
		@vor_offsety = boundingrect.bottom / 2

		begin
			@fs_socket = TCPSocket.open('localhost', FS_PORT)
			@fs_socket.puts "reset"
		rescue
			#swallow all errors
		end
		
		if FileTest.directory?(MAPSDIR) then
			$MAPSHOME = MAPSDIR
		else
			resp = Qt::MessageBox::question(nil, "No local Map Directory found.", "Create one?", Qt::MessageBox::No, Qt::MessageBox::Yes)
			if resp == Qt::MessageBox::Yes then
				Dir.mkdir(MAPSDIR)
				$MAPSHOME = MAPSDIR
			else
				$MAPSHOME = "./"
			end
		end
		puts "Map Directory located here: \"#{$MAPSHOME}\""
		
		readFlightgear()
	end

	def resetScene
		@scene.clear
		@openstreetmapLayer = TileGraphicsItemGroup.new
		@openstreetmapLayer.setZValue(Z_VALUE_TILES)
		@openstreetmapLayer.setOpacity(@opacity)
		@scene.addItem(@openstreetmapLayer)
		@elevationLayer = Qt::GraphicsItemGroup.new
		@elevationLayer.setZValue(Z_VALUE_TILES_ELEVATION)
		@scene.addItem(@elevationLayer)
		
		@w.hSopacity.setValue((@opacity * 100).to_i)
	end

	def get_data(path)
		# check from end to get most recent position
		r=@fs_ans.reverse.detect do |f|
			f.include?(path)
		end
		r =~ /'(-?\d+\.\d+)' \(double\)/
		return $1.to_f
	end

	def putflag(x,y,i,node)
		flag=FlagGraphicsPixmapItem.new(@flag)
		flag.setOffset(x - OFFSET_FLAG_X, y - OFFSET_FLAG_Y)
		t=Qt::GraphicsTextItem.new(i.to_s, flag)
		t.setPos(x + OFFSET_FLAG_COUNTER_X, y + OFFSET_FLAG_COUNTER_Y)
		flag.setZValue(Z_VALUE_WAYPOINT)
		tooltip=("Lon: %.3f°"%node.lon)+("\nLat: %.3f°"%node.lat)
		if node.elevation>0 then
			tooltip += ("\nElevation: %.1fm" % node.elevation)
		end
		flag.setToolTip(tooltip)
		@scene.addItem(flag)
	end

	def nextcolor
		col=@colors[:selection][@colors[:index]]
		if col.nil? then
			col=@colors[:selection][0]
			@colors[:index] = 0
		else
			@colors[:index] += 1
		end
		return col
	end

	def savetrack(items, warn=true)
		if items[0].nil? or items[0].nodes.length == 0 then
			Qt::MessageBox::warning(nil, "Warning", "No data recorded yet.") if warn
		else
			begin
				Dir.mkdir($MAPSHOME + "/tracks")
			rescue Errno::EEXIST
				# just swallow error
			end
		
			ap "generating xml-doc"
			doc = REXML::Document.new 
			doc << REXML::XMLDecl.new(REXML::XMLDecl::DEFAULT_VERSION, REXML::XMLDecl::DEFAULT_ENCODING)

			doc.add_element('gpx')

			node=REXML::XPath.first(doc, "//gpx")
			node.add_namespace("http://www.topografix.com/GPX/1/1")
			node.add_attributes({'creator'=>"ruby-tracker", "version"=>"1.1"} )
			node.add_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

			tracknode = REXML::Element.new("trk")
			node.add_element(tracknode)
			items.each{|track|
				segnode = REXML::Element.new("trkseg")
				tracknode.add_element(segnode)
				track.nodes.each{|n|
					trackpoint = REXML::Element.new("trkpt")
					trackpoint.add_attributes({"lat" =>	n.lat.to_s.gsub(",","."), "lon" => n.lon.to_s.gsub(",",".")})
					trackpoint.add_text_element("ele", n.elevation.to_s.gsub(",","."))
					trackpoint.add_text_element("time", n.toGPStime)
					trackpoint.add_text_element("time_us", n.timestamp.usec.to_s)
					segnode.add_element(trackpoint)
				}
			}
			File.open($MAPSHOME + "/tracks/" + items.first.nodes.first.toGPStime + ".gpx", "w+"){|f|
				begin
					doc.write(f, 2)
				rescue Errno::EISDIR
					Qt::MessageBox::warning(nil, "Warning", "You selected a directory, not a file. Nothing saved.")
				end
			}
			ap "xml-file written"
		end
	end
	
	def loadtrack(title)	
		fn=Qt::FileDialog::getOpenFileName(nil, title, $MAPSHOME + "/tracks/", "Track-Data (*.gpx *.log);;All (*)")
		if !fn.nil? then
			success = false
			file=File.new(fn)
			begin
				doc = REXML::Document.new(file)

				doc.elements.each("/gpx/trk") do |trk|
					@mytrack_current -= 1
					trk.elements.each("trkseg") do |seg|
						@mytrack_current += 1
						if @mytracks[@mytrack_current].nil? then
							@mytracks[@mytrack_current] = Way.new(1, 'user', Time.now, nextcolor)
							@prev_track_node = nil
						end
						track=@mytracks[@mytrack_current]
						track.nodes.clear
						seg.elements.each("trkpt") do |tpt|
							usec = tpt.elements["time_us"].text.strip
							usec = (usec.nil? ? "0" : usec)
							loc = tpt.attributes # lon and lat as a hash
							track << Node.new(nil, tpt.elements["time"].text.strip + usec, \
									loc["lon"].to_f, loc["lat"].to_f, \
									tpt.elements["ele"].text.to_f)
							success = true
						end
					end
				end
			rescue Errno::EISDIR
				# swallow error, "success" is false anyway
			end

			if success then
				movemap(@node, true)
			else
				Qt::MessageBox::warning(nil, "Warning", "No data found in file.")
			end
			return success
		end
	end

	def loadwaypoint(title)	
		fn=Qt::FileDialog::getOpenFileName(nil, title, $MAPSHOME + "/waypoints/", "Waypoint-Data (*.gpx *.log);;All (*)")
		if !fn.nil? then
			success = false
			file=File.new(fn)
			begin
				doc = REXML::Document.new(file)
				@waypoints = Way.new(nil,'user', Time.now, "Blue")
				doc.elements.each("/gpx/wpt") do |wpt|
					loc = wpt.attributes # lon and lat as a hash
					@waypoints << Node.new(nil, wpt.elements["time"].text.strip,
								loc["lon"].to_f, loc["lat"].to_f, \
								wpt.elements["ele"].text.to_f)
					success = true
				end
				file.close
				if success then
					movemap(@node, true)
				else
					Qt::MessageBox::warning(nil, "Warning", "No data found in file.")
				end
				return success
			rescue Errno::EISDIR
				Qt::MessageBox::warning(nil, "Warning", "You selected a directory, not a file. Nothing loaded.")
				return success
			end
		end
	end

	def saveWaypoints(waypoints)
		if waypoints.length == 0 then
			Qt::MessageBox::warning(nil, "Warning", "No waypoints set yet.") if warn
		else
			begin
				Dir.mkdir($MAPSHOME + "/waypoints")
			rescue Errno::EEXIST
				# just swallow error
			end
		
			doc = REXML::Document.new 
			doc << REXML::XMLDecl.new(REXML::XMLDecl::DEFAULT_VERSION, REXML::XMLDecl::DEFAULT_ENCODING)

			doc.add_element('gpx')
			root=REXML::XPath.first(doc, "//gpx")
			root.add_namespace("http://www.topografix.com/GPX/1/1")
			root.add_attributes({'creator'=>"ruby-tracker", "version"=>"1.1"} )
			root.add_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

			waypoints[0].nodes.each{|n|
				if !n.nil? then
					wpnode = REXML::Element.new("wpt")
					root.add_element(wpnode)
					wpnode.add_attributes({"lat" =>	n.lat.to_s.gsub(",","."), "lon" => n.lon.to_s.gsub(",",".")})
					wpnode.add_text_element("ele", n.elevation.to_s.gsub(",","."))
					wpnode.add_text_element("time", n.toGPStime)
				end
			}

			fn=Qt::FileDialog::getSaveFileName(nil, "Save Waypoint File", $MAPSHOME + "/waypoints/", "Waypoint-Data (*.gpx *.log);;All (*)","*.gpx")
			if !fn.nil? then
				if fn !~ /\.gpx$/ then
					fn += ".gpx"
				end
				File.open(fn, "w+"){|f|
					begin
						doc.write(f, 2)
					rescue Errno::EISDIR
						Qt::MessageBox::warning(nil, "Warning", "You selected a directory, not a file. Nothing saved.")
					end
				}
			end
		end
	end
	
	def zoomplus
		@httpThreads.each do |th|
			th.kill
		end
		@httpThreads = Array.new
		@currentlyDownloading = Array.new
		@currentlyDownloadingElevation = Array.new
		@remainingTiles = 0
		@scene.removeItem(@warningText)

		@zoom += 1
		@zoom=17 if @zoom>17
		@zoom=3 if @zoom<3
		@w.lBzoom.setText(@zoom.to_s)
		@node.zoom(@zoom)
		@offset_x *= 2
		@offset_y *= 2
		movemap(@node, true)
	end

	def zoomminus 
		@httpThreads.each do |th|
			th.kill
		end
		@remainingTiles = 0
		@httpThreads = Array.new
		@currentlyDownloading = Array.new
		@currentlyDownloadingElevation = Array.new
		@scene.removeItem(@warningText)

		@zoom -= 1
		@zoom=17 if @zoom>17
		@zoom=3 if @zoom<3
		@w.lBzoom.setText(@zoom.to_s)
		@node.zoom(@zoom)
		@offset_x /= 2
		@offset_y /= 2
		movemap(@node, true)
	end

	def addTileToScene(f, origin_x, origin_y, thread=false)
		@scene_tiles << f
		f =~ /\/(\d*)\/(\d*)\/(\d*)/
		x = $2.to_i
		y = $3.to_i

		if thread then
			# we can not add the tiles to the scene within this thread directly. It crosses thread
			# bounderies which crashes QT badly
			@tilesToAddMutex.synchronize {
				@tilesToAdd << [f+".png", (x - origin_x)*256, (y - origin_y)*256, OPENSTREETMAP_TILE]
			}
		else # add immediately, we are not in a different thread
			pmi=Qt::GraphicsPixmapItem.new(Qt::Pixmap.new(f+".png"), @openstreetmapLayer)
			pmi.setOffset((x - origin_x)*256, (y - origin_y)*256)
		end

		if @w.cBshadows.isChecked then
			if FileTest.exist?(f + "-elevation.png") then
				if thread then
					# we can not add the tiles to the scene within this thread directly. It crosses thread
					# bounderies which crashes QT badly
					@tilesToAddMutex.synchronize {
						@tilesToAdd << [f, (x - origin_x)*256, (y - origin_y)*256, ELEVATION_TILE]
					}
				else
					pmi = Qt::GraphicsPixmapItem.new(Qt::Pixmap.new(f + "-elevation.png"), @elevationLayer)
					pmi.setOffset((x - origin_x)*256, (y - origin_y)*256)
					pmi.setZValue(Z_VALUE_TILES_ELEVATION)
				end
			else
				@httpThreads << Thread.new(f) {|filename|
					if !@currentlyDownloadingElevation.include?(filename) then
						@currentlyDownloadingElevation << filename
						# try to download elevation profile
						@httpElevationMutex.synchronize {
							h = Net::HTTP.new('toolserver.org')
							h.open_timeout = 10
							filename =~ /\/\d+\/\d+\/\d+$/
							fn = $&
							begin
								resp, data = h.request_get("/~cmarqu/hill" + fn + ".png", nil)
								if resp.kind_of?(Net::HTTPOK) then
									# check here again as in the meantime another thread might already have added the tile
									if !FileTest.exist?($MAPSHOME + fn + "-elevation.png") then
										File.open($MAPSHOME + fn + "-elevation.png", "w") do |file|
											file.syswrite(data)
										end
										@tilesToAddMutex.synchronize {
											@tilesToAdd << [$MAPSHOME + fn + "-elevation.png", (x - origin_x)*256, (y - origin_y)*256, ELEVATION_TILE]
										}
									end
								else
									puts "No elevation profile found for this tile."
								end
							# NoMethodError because of bug, see http://redmine.ruby-lang.org/issues/show/2708
							rescue NoMethodError, Errno::ECONNREFUSED, SocketError, Timeout::Error
								puts "No connection to elevation profile server."
							end
						} # sync
						@currentlyDownloadingElevation.delete(filename)
					end # if downloading
				} # Thread
			end
		end
	end

	def addNavToScene(vor, origin_x, origin_y)
		vorGraphic = Qt::GraphicsSvgItem.new(":/icons/vor.svg")
		vorGraphic.setElementId(vor.type)
		vorGraphic.setTransform(Qt::Transform.new.translate(-@vor_offsetx, -@vor_offsety))
		vorGraphic.setZValue(Z_VALUE_NAV)
		@scene.addItem(vorGraphic)
		vorNode = Node.new(0, nil, vor.lon.to_f, vor.lat.to_f)
		vorGraphic.setPos((vorNode.toxtile - origin_x) * 256, (vorNode.toytile - origin_y) * 256)
		vorGraphic.baseElement = vor
		vor.sceneItem = vorGraphic
		
		# create text on Navaid
		textString = vor.shortName + " " + vor.freq.to_s
		text=Qt::GraphicsSimpleTextItem.new(textString)
		text.setFont(@graphicsSceneFont)
		bounding = text.boundingRect
		background = Qt::GraphicsRectItem.new(bounding)
		background.setBrush(@graphicsSceneBrush)
		background.setPen(@noPen)
		background.setToolTip(textString + "; " + vor.longName)
		background.setPos(@vor_offsetx - bounding.width / 2, 2*@vor_offsety+3)
		text.setParentItem(background)
		background.setParentItem(vorGraphic)
	end
	
	def addRunwayToScene(rw, origin_x, origin_y)
		rwNode = Node.new(0, nil, rw.lon.to_f, rw.lat.to_f)
		
		# create text
		textString = rw.airportName + " " + rw.freq.to_s
		text=Qt::GraphicsSimpleTextItem.new(textString)
		text.setFont(@graphicsSceneFont)
		bounding = text.boundingRect
		background = Qt::GraphicsRectItem.new(bounding)
		background.setTransform(Qt::Transform.new.translate(-bounding.width / 2, ILSTEXTOFFSET))
		background.setZValue(Z_VALUE_NAV)
		background.setBrush(@graphicsSceneBrush)
		background.setPen(@noPen)
		background.setToolTip(textString)
		text.setParentItem(background)
		background.setPos((rwNode.toxtile - origin_x) * 256, (rwNode.toytile - origin_y) * 256)

		rwGraphic = Qt::GraphicsEllipseItem.new(0,0,ILSSIZE,ILSSIZE)
		rwGraphic.setStartAngle(ILSCONEANGLE*8)
		rwGraphic.setSpanAngle(-ILSCONEANGLE*16)
		rwGraphic.setTransform(Qt::Transform.new.translate(bounding.width/ 2, -ILSTEXTOFFSET).rotate(rw.direction + 90).translate(-ILSSIZE / 2, -ILSSIZE / 2))
		rwGraphic.setPen(@noPen)
		rwGraphic.setBrush(@ilsBrush)
		rwGraphic.setFlag(Qt::GraphicsItem::ItemStacksBehindParent)

		rwGraphic.setParentItem(background)
		@scene.addItem(background)
		rw.sceneItem = background
	end
	
	def movemap(node, repaint=false, downloadTiles=true)
		origin_x=node.xtile
		origin_y=node.ytile

		if repaint then
			@scene_tiles = []
			@scene_navs = []
			@scene_rws = []
			resetScene()
			# 8 => 256 = 2**8
			size = 2**(@zoom + 8)
			sceneRect = Qt::RectF.new(0,0,size,size)
			sceneRect.moveCenter(Qt::PointF.new(@node.xtile, @node.ytile))
			@scene.setSceneRect(sceneRect)
		end

		vorsToDisplay = @navs.getVORs(node.getLatLonBox(@w.gVmap.size, @offset_x, @offset_y))
		if vorsToDisplay.length < MAXVORSTODISPLAY then
			vorsToDisplay.each do |vor|
				if !@scene_navs.include?(vor)
					if (@w.cBndb.isChecked and vor.type == "NDB") or
							(@w.cBvor.isChecked and vor.type != "NDB") then
						@scene_navs << vor
						addNavToScene(vor, origin_x, origin_y)
					end
				end
			end
		elsif !@scene_navs.empty? then
			repaint = true
			@scene_tiles = []
			@scene_navs = []
			@scene_rws = []
			resetScene()
		end

		if @w.cBrw.isChecked then
			runwaysToDisplay = @navs.getRunways(node.getLatLonBox(@w.gVmap.size, @offset_x, @offset_y))
			if runwaysToDisplay.length < MAXILSTODISPLAY then
				runwaysToDisplay.each do |runway|
					if !@scene_rws.include?(runway)
						@scene_rws << runway
						addRunwayToScene(runway, origin_x, origin_y)
					end
				end
			end
		elsif !@scene_rws.empty? then
			repaint = true
			@scene_tiles = []
			@scene_navs = []
			@scene_rws = []
			resetScene()
		end

		fn = node.getfilenames(@w.gVmap.size, @offset_x, @offset_y)

		fn.each{|f|
			if !@scene_tiles.include?(f) then
				if FileTest.exist?(f+".png") then
					addTileToScene(f, origin_x, origin_y)
				elsif downloadTiles and (@timeNoInternet.nil? or (Time.now - @timeNoInternet) > 60) then
					@httpThreads << Thread.new(f) {|filename|
						# check if we already download this tile
						if !@currentlyDownloading.include?(filename) then
							@currentlyDownloading << filename
							@remainingTiles += 1
							@httpMutex.synchronize {
								h = Net::HTTP.new('tile.openstreetmap.org')
								h.open_timeout = 10
								filename =~ /\/\d+\/\d+\/\d+$/
								fn = $&
								begin
									resp, data = h.request_get(fn + ".png", nil)
									if resp.kind_of?(Net::HTTPOK) then
										maindir = Dir.pwd
										Dir.chdir($MAPSHOME)
										fn.split("/")[0..-2].each do |dir|
											if !dir.empty? then
												begin
													Dir.mkdir(dir) 
												rescue Errno::EEXIST
													# just swallow error
												end
												Dir.chdir(dir)
											end
										end
										Dir.chdir(maindir)
										File.open($MAPSHOME + fn + ".png", "w") do |file|
											file.syswrite(data)
										end
										# we call from within a thread, signal this to the subroutine
										addTileToScene($MAPSHOME + fn, origin_x, origin_y, true)
									else
										puts "Could not download tile. Internet connection alive?"
										@timeNoInternet=Time.now
									end
								# NoMethodError because of bug, see http://redmine.ruby-lang.org/issues/show/2708
								rescue NoMethodError, Errno::ECONNREFUSED, SocketError, Timeout::Error
									puts "Could not download tile. Internet connection alive?"
									@timeNoInternet=Time.now
								end
							}
							@remainingTiles -= 1
							@currentlyDownloading.delete(filename)
						end # if
					}
				else
					puts "Internet timeout still running"
				end
			end
		}
		
		if repaint then
			mainnode_x=node.toxtile
			mainnode_y=node.toytile

			# set waypoint flags
			i=1
			@waypoints.nodes.each {|node|
				if !node.nil? then
					putflag((node.toxtile - mainnode_x) * 256, (node.toytile - mainnode_y) * 256, i, node)
				end
				i+=1
			}
			# set origin pin
			pmi=Qt::GraphicsPixmapItem.new(@pin)
			pmi.setOffset(OFFSET_PIN_X, -OFFSET_PIN_Y)
			pmi.setZValue(Z_VALUE_ORIGIN)
			@scene.addItem(pmi)

			# create hud display
			# needs to be embedded in other graphics element to circumvent a bug if the position of
			# the ProxyWidget is above, below 2**15 - 1, bug in QT
			@hud=Qt::GraphicsRectItem.new(0,0,10,10)
			@hud.setPen(@noPen)
			hud=Qt::GraphicsProxyWidget.new(@hud)
			@hud_widget = HudWidget.new()
			hud.setWidget(@hud_widget)
			@hud.setZValue(Z_VALUE_HUD)
			@scene.addItem(@hud)
			@hud.setPos(@w.gVmap.mapToScene(0,0))
			
			# create rose
			@rose=Qt::GraphicsSvgItem.new(":/icons/rose.svg")
			@rose.setElementId("rose")
			boundingrect = @rose.boundingRect
			rose_offsetx = boundingrect.right / 2
			rose_offsety = boundingrect.bottom / 2
			@rose.setTransform(Qt::Transform.new.scale(SCALE_SVG,SCALE_SVG).translate(-rose_offsetx, -rose_offsety))
			@rose.setZValue(Z_VALUE_ROSE)
			@scene.addItem(@rose)
			@rose.setPos((@posnode.toxtile - mainnode_x) * 256, (@posnode.toytile - mainnode_y) * 256)

			# create bearing-pointer
			@pointer=Qt::GraphicsSvgItem.new(":/icons/rose.svg")
			@pointer.setElementId("zeiger")
			boundingrect = @pointer.boundingRect
			@pointer_offsetx = boundingrect.right / 2
			@pointer.setTransform(Qt::Transform.new.scale(SCALE_SVG,SCALE_SVG).rotate(0).translate(-@pointer_offsetx, 0))
			@pointer.setZValue(Z_VALUE_POINTER)
			@scene.addItem(@pointer)
			@pointer.setPos((@posnode.toxtile - mainnode_x) * 256, (@posnode.toytile - mainnode_y) * 256)

			# create pointer to origin
			@pointertoorigin=Qt::GraphicsSvgItem.new(":/icons/rose.svg")
			@pointertoorigin.setElementId("zeigertoorigin")
			boundingrect = @pointertoorigin.boundingRect
			@pointertoorigin_offsetx = boundingrect.right / 2
			@pointertoorigin.setTransform(Qt::Transform.new.scale(SCALE_SVG,SCALE_SVG).rotate(0).translate(-@pointertoorigin_offsetx, 0))
			@pointertoorigin.setZValue(Z_VALUE_POINTERTOORIGIN)
			@scene.addItem(@pointertoorigin)
			@pointertoorigin.setPos((@posnode.toxtile - mainnode_x) * 256, (@posnode.toytile - mainnode_y) * 256)
			
			# paint tracks
			@mytracks.each {|track|
				prev_node = nil
				if !track.nil? then
					@linepen.setColor(Qt::Color.new(track.color))
					tck=nil
					prev_node=false
					if !track.nodes.empty? then
						track.nodes.each{|n|
							if !prev_node then
								tck=Qt::PainterPath.new(Qt::PointF.new((n.toxtile - mainnode_x) * 256, (n.toytile - mainnode_y) * 256))
							else
								tck.lineTo((n.toxtile - mainnode_x) * 256, (n.toytile - mainnode_y) * 256)
							end
							prev_node = true
						}
						track.path=TrackGraphicsPathItem.new(track)
						track.path.setPath(tck)
						track.path.setZValue(Z_VALUE_TRACK)
						track.path.setPen(@linepen)
						@scene.addItem(track.path)
					end
				end
			}
			if @w.pBrecordTrack.isChecked then
				if !@mytracks[@mytrack_current].path.nil?
					@tckpath=@mytracks[@mytrack_current].path.path
				end
			end
		end

		@w.gVmap.centerOn(@offset_x*256,@offset_y*256)
		if !@hud.nil? then
			@hud.setPos(@w.gVmap.mapToScene(0,0))
		end
	end

	def readFlightgear
		Thread.new do
			while true
				if @fs_socket.nil? then
					sleep 1
				else
					begin
						@queryMutex.synchronize {
							@fs_queries.each do |q|
								@fs_socket.print("get " + q + "\r\n")
								s=""
								while select([@fs_socket], nil, nil, 0.8) do
									s += @fs_socket.read(1)
									# check for end of line characterized by this string: "\r\n/>"
									break	if s[-4..-1] == "\r\n/>" and s.include?(q)
								end
								if s.include?(q) then
									@fs_ans << s.split("\n")
									@fs_ans.flatten!
								end
							end
						}
					rescue
						puts "Warning: Can not communicate with Flightsimulator. Is Telnet interface configured?"
						@scene.removeItem(@rose)
						@scene.removeItem(@pointer)
						@fs_socket = nil
						@hud = nil
					end
				end
			end #while
		end # Thread
	end

	def wakeupTimer()
#		p "wakeup in"
		# have to do centering every time as QT will not scroll to scene coordinates which have no elements placed there yet
		begin
			@w.gVmap.centerOn(@offset_x*256,@offset_y*256)
		rescue ArgumentError
			# swallow
		end

		@wakeupCounter += 1
		if @wakeupCounter <= TICKSTOSKIP then
			# trick to prevent threads from getting just tiny slices of time to execute 
			# inside the main event loop of QT
			sleep LOOPSLEEPINTERVAL
			return
		end
		@wakeupCounter = 0

		# add tiles which are awaiting addition				
		@tilesToAddMutex.synchronize {
			@tilesToAdd.each do |tile|
				parent = (tile[3] == OPENSTREETMAP_TILE) ? @openstreetmapLayer : @elevationLayer
				pmi = Qt::GraphicsPixmapItem.new(Qt::Pixmap.new(tile[0]), parent)
				pmi.setOffset(tile[1], tile[2])
			end
			@tilesToAdd.clear
		}

		if @remainingTiles > 0 then
			if @warningText.nil? then
				@warningText = Qt::GraphicsSimpleTextItem.new()
				@warningText.setBrush(Qt::Brush.new(Qt::Color.new("red")))
				@warningText.setZValue(Z_VALUE_WARNING)
				@scene.addItem(@warningText)
			end
			fontInfo = Qt::FontInfo.new(@warningText.font)
			@warningText.setText("#{@remainingTiles} remaining tiles")
			@warningText.setPos(@w.gVmap.mapToScene((@w.gVmap.size.width - @warningText.boundingRect.width)/2, 
						@w.gVmap.size.height - fontInfo.pixelSize - 10))
		elsif !@warningText.nil? then
			@scene.removeItem(@warningText)
			@warningText = nil
		end

		if @fs_socket.nil? then
			begin
				@fs_socket = TCPSocket.open('localhost', FS_PORT)
				movemap(@node, true)
			rescue
				#swallow all errors
				puts "Non-critical socket error: #{$!}"
			end
		else
			#ap @fs_ans
			if @fs_ans.length>0 then # check if any answer has been received yet.
				if !@hud.nil? then
					@tempposnode.lon = get_data("/position/longitude-deg")
					@tempposnode.lat = get_data("/position/latitude-deg")
					@rot = get_data("/orientation/heading-deg")
					@alt = get_data("/position/altitude-ft")
					@speed = get_data("/velocities/groundspeed-kt")
					# protect against invalid data
					if !(@tempposnode.lon and @tempposnode.lat and @rot and @alt and @speed) then
						@fs_ans=[]
						return
					end
					@posnode = @tempposnode.dup
					
					@speed = @speed  * 1.852
					@hud_widget.w.lBlat.setText("%2.3f°" % @posnode.lat)
					@hud_widget.w.lBlon.setText("%2.3f°" % @posnode.lon)
					conversion = @metricUnit ? 1 : 0.54
					@hud_widget.w.lBspeed.setText("%3.1f" % (@speed*conversion) +  (@metricUnit ? " km/h" : "kt"))
					@hud_widget.w.lBheading.setText("%3.1f°" % (@rot))
					conversion = @metricUnit ? 3.281 : 1
					@hud_widget.w.lBalt.setText("%3.1f" % (@alt/conversion) +  (@metricUnit ? "m" : "ft"))
					mainnode_x=@node.toxtile
					mainnode_y=@node.toytile
					@rose.setPos((@posnode.toxtile - mainnode_x) * 256, (@posnode.toytile - mainnode_y) * 256)
					
					@pointer.setTransform(Qt::Transform.new.scale(SCALE_SVG,SCALE_SVG).rotate(@rot+180.0) \
							.translate(-@pointer_offsetx, -@pointer_offsetx))
					@pointer.setPos((@posnode.toxtile - mainnode_x) * 256 ,(@posnode.toytile - mainnode_y) * 256)
					
					to_x = mainnode_x
					to_y = mainnode_y
					to_lon = @node.lon
					to_lat = @node.lat
					if !@w.cBtoorigin.isChecked and !@waypoints.currentwp.nil? then
						if !@waypoints.nodes[@waypoints.currentwp-1].nil? then
							to_x = @waypoints.nodes[@waypoints.currentwp-1].toxtile
							to_y = @waypoints.nodes[@waypoints.currentwp-1].toytile
							to_lon = @waypoints.nodes[@waypoints.currentwp-1].lon
							to_lat = @waypoints.nodes[@waypoints.currentwp-1].lat
						end
					end
					@pointertoorigin.setTransform(Qt::Transform.new.scale(SCALE_SVG,SCALE_SVG).rotateRadians(Math::PI / 2 + \
							Math.atan2((@posnode.toytile - to_y), (@posnode.toxtile - to_x))) \
							.translate(-@pointertoorigin_offsetx, -@pointertoorigin_offsetx))
					@pointertoorigin.setPos((@posnode.toxtile - mainnode_x) * 256 ,(@posnode.toytile - mainnode_y) * 256)
					
					@hud_widget.w.lBdistance.text = @posnode.distanceto_str(to_lon, to_lat)
					
					if @w.cBautocenter.isChecked then
						@offset_x = @posnode.toxtile - mainnode_x
						@offset_y = @posnode.toytile - mainnode_y
						movemap(@node)
					end
					if @mytrack_current >= 0 and @w.pBrecordTrack.isChecked then
						if @mytracks[@mytrack_current].nil? then
							@mytracks[@mytrack_current] = Way.new(1, 'user', Time.now, nextcolor)
							@linepen.setColor(Qt::Color.new(@mytracks[@mytrack_current].color))
							@prev_track_node = false
						end
						@mytracks[@mytrack_current] << Node.new(nil, Time.now, @posnode.lon, @posnode.lat, @alt / 3.281)
						n = @mytracks[@mytrack_current].nodes.last
						n.speed = @speed
						if !@prev_track_node then
							@tckpath = Qt::PainterPath.new(Qt::PointF.new((n.toxtile - mainnode_x) * 256, (n.toytile - mainnode_y) * 256))
							@mytracks[@mytrack_current].path=TrackGraphicsPathItem.new(@mytracks[@mytrack_current])
							@mytracks[@mytrack_current].path.setPath(@tckpath)
							@mytracks[@mytrack_current].path.setZValue(Z_VALUE_TRACK)
							@mytracks[@mytrack_current].path.setPen(@linepen)
							@scene.addItem(@mytracks[@mytrack_current].path)
							@prev_track_node = true
						else
							@tckpath.lineTo((n.toxtile - mainnode_x) * 256, (n.toytile - mainnode_y) * 256)
							@mytracks[@mytrack_current].path.setPath(@tckpath)
						end
					end
					
				end # if !@hud.nil?
			end # if @fs_ans.length>0
			@fs_ans=[]
		end # socket nil
#		p "wakeupTimer out"
	end
	

	def writeFlightsim(element)
		@queryMutex.synchronize {
			@fs_socket.print(element + "\r\n")
			s = ""
			while select([@fs_socket], nil, nil, 0.3) do
				s += @fs_socket.read(1)
				# check for end of line characterized by this string: "\r\n/>"
				break	if s[-4..-1] == "\r\n/>"
			end
		}
	end


	def autosaveTimer()
		savetrack(@mytracks, false)
	end
	
	def pBrecordTrack_toggled(state)
		if state
			@mytrack_current += 1
			@w.pBrecordTrack.text = "Recording Track #{@mytrack_current + 1}"
			if @mytracks[@mytrack_current].nil? then
				@mytracks[@mytrack_current] = Way.new(1, 'user', Time.now, nextcolor)
				@linepen.setColor(Qt::Color.new(@mytracks[@mytrack_current].color))
				@prev_track_node = false
			end
		else
			@w.pBrecordTrack.text = "Record Track #{@mytrack_current + 2}"
		end
	end
	
	def cBpointorigin_clicked()
		@w.fRcurrentwp.enabled = !@w.cBtoorigin.isChecked()
	end
	
	def pBminus_clicked()
		zoomminus
	end
		
	def pBplus_clicked()
		zoomplus
	end
	
	def pBexit_clicked()
		puts "Syncing data and exiting."
		@cfg.setValue("metricUnit", Qt::Variant.new(@metricUnit))
		@cfg.setValue("zoom", Qt::Variant.new(@zoom))
		@cfg.setValue("lat", Qt::Variant.new(@node.lat))
		@cfg.setValue("lon", Qt::Variant.new(@node.lon))
		@cfg.setValue("rwChecked", Qt::Variant.new(@w.cBrw.isChecked))
		@cfg.setValue("nbdChecked", Qt::Variant.new(@w.cBndb.isChecked))
		@cfg.setValue("vorChecked", Qt::Variant.new(@w.cBvor.isChecked))
		@cfg.setValue("opacity", Qt::Variant.new(@opacity))
		@cfg.sync
		@parent.close
	end
	
	def cBvor_clicked()
		movemap(@node, true)
	end
	 
	def cBndb_clicked()
		movemap(@node, true)
	end

	def cBrw_clicked()
		movemap(@node, true)
	end
	
	def cBshadows_clicked()
		movemap(@node, true)
	end
	
	def resizeEvent(e)
		super
		movemap(@node, true)
	end
	
	def keyPressEvent(keyevent)
		case keyevent.text
			when "+"
				zoomplus
			when "-"
				zoomminus
			when " "
				@w.pBrecordTrack.click
			else # case
				super
		end # case
	end

	def hSopacity_changed(opacity)
		@opacity = opacity / 100.0
		@openstreetmapLayer.setOpacity(@opacity)
	end
end



class FlagGraphicsPixmapItem < Qt::GraphicsPixmapItem
	def initialize(*k)
		super
	end
	
	def mousePressEvent(mouseEvent)
		if mouseEvent.button == Qt::LeftButton then
			dlg=mouseEvent.widget.parent.parent
			dlg.waypoints.currentwp = childItems[0].toPlainText.to_i
			dlg.w.lBcurrentwp.text = childItems[0].toPlainText
		else
			super
		end
	end
end


class TrackGraphicsPathItem < Qt::GraphicsPathItem
	attr_reader :nodeinfo, :nodeinfo_widget
	
	@@nodeinfo_array = Array.new
	
	def initialize(parent)
		super()
		@parent=parent
		@addToScene = true

		# needs to be embedded in other graphics element to circumvent a bug if the position of
		# the ProxyWidget is above, below 2**15 - 1, bug in QT
		@nodeinfo = Qt::GraphicsRectItem.new(0,0,100,100)
		@nodeinfo.setPen(Qt::Pen.new(Qt::NoPen))

		@nodeinfow = Qt::GraphicsProxyWidget.new(@nodeinfo)
		@nodeinfo_widget = NodeinfoWidget.new(@nodeinfo)
		@nodeinfo_widget.setAttribute(Qt::WA_Hover)
		@nodeinfow.setWidget(@nodeinfo_widget)
		@nodeinfo.setZValue(Z_VALUE_HUD)
		@nodeinfo.setAcceptHoverEvents(true)
		@nodeinfo.setVisible(false)
		setAcceptHoverEvents(true)
		setHandlesChildEvents(true)

		# store these elements in permanent array
		# otherwise GC will remove them and then causes core-dumps in QT
		@@nodeinfo_array << [@nodeinfow, @nodeinfo_widget]
	end
	
	def colorize(data, dlg)
		scene=dlg.scene
		prev_x = path.elementAt(0).x
		prev_y = path.elementAt(0).y
		group = Qt::GraphicsItemGroup.new
		x = y = 0
		pen=Qt::Pen.new
		pen.setWidth(5)
		line=nil
		d=data.dup
		d.delete_if{|e| e<=0.0 }
		if d.length==0 then
			Qt::MessageBox::warning(nil, "Warning", "No elevation/speed data found in track.")
			return
		end
		max=d.max
		min=d.min
		delta=max-min
		color=nil
		1.upto(path.elementCount-2){|i|
			color=Qt::Color.new
			if data[i]>0.0 then
				color.setHsv((data[i]-min)/delta * COLORRANGE_DEG + COLOROFFSET_DEG,255,255)
			else
				color.setRgb(100,100,100)
			end
			pen.setColor(color)
			x = path.elementAt(i).x
			y = path.elementAt(i).y
			line = Qt::GraphicsLineItem.new(prev_x, prev_y, x, y)
			line.setPen(pen)
	 		line.setZValue(Z_VALUE_TRACK_COLORED)
			group.addToGroup(line)
			prev_x = x
			prev_y = y
		}
 		group.setZValue(Z_VALUE_TRACK_COLORED)
 		scene.addItem(group)
		
	end
	
	def contextMenuEvent(contextEvent)
		dlg=contextEvent.widget.parent.parent
		entries=["Colorize Altitude", "Colorize Speed"]
		menu=Qt::Menu.new
		entries.each{|e|
			if e=="-" then
				menu.addSeparator
			else
				menu.addAction(e)
			end
		}
		sel=menu.exec(contextEvent.screenPos)
		sel=sel.text if !sel.nil?
		data=[]
		case sel
			when entries[0]
				@parent.nodes.each{|n|
					data << n.elevation
				}
				colorize(data, dlg)
				
			when entries[1]
				@parent.nodes.each{|n|
					data << n.speed
				}
				colorize(data, dlg)
				
		end # case
	end

	def hoverMoveEvent(hoverEvent)
#		ap "hovermove in"
		dlg=hoverEvent.widget.parent.parent

		if @addToScene then
			dlg.scene.addItem(@nodeinfo)
			@addToScene = false
		end
		
		if !@nodeinfo_widget.hover_on then
			@nodeinfo.setVisible(true)
			@nodeinfo_widget.hover_on = true
		end
		x=hoverEvent.pos.x
		y=hoverEvent.pos.y
		e=nil
		hit=nil
		1.upto(self.path.elementCount-1){|i|
			e=self.path.elementAt(i)
			if ((e.x - x).abs < 3) and ((e.y - y).abs < 3)then
				hit=i
				break
			end
		}
		
		if !hit.nil? and !@parent.nil? then
			n=@parent.nodes[hit]
			@nodeinfo_widget.w.lBlon.text="%.3f°" % n.lon
			@nodeinfo_widget.w.lBlat.text="%.3f°" % n.lat
			@nodeinfo_widget.w.lBalt.text="%.1fm" % n.elevation
			@nodeinfo_widget.w.lBspeed.text="%.1fkm/h" % n.speed
			@nodeinfo_widget.w.lBdist.text="%.2fkm" % (@parent.distance(n) / 1000)
			@nodeinfo_widget.w.lBtime.text=@parent.duration_str
			pos = mapToScene(hoverEvent.pos)
			if !@nodeinfo.isVisible or @nodeinfo_widget.hover_widget_pos.nil? or (!@nodeinfo_widget.hover_widget_pos.nil? \
						and Qt::LineF.new(@nodeinfo_widget.hover_widget_pos, pos).length > 30) then
				dlg.scene.items.each {|item|
					if item.kind_of? Qt::GraphicsRectItem then
						if item != @nodeinfo then
					#		item.setVisible(false)
						end
					end
				}
				@nodeinfo.setVisible(true)
				@nodeinfo_widget.hover_widget_pos=pos
				@nodeinfo.setPos(pos)
				@nodeinfo_widget.hovertimer.stop
			end
		end
#		ap "hovermove out"
	end
	
	def hoverLeaveEvent(hoverEvent)
#		ap "hoverleave in"
		if @nodeinfo_widget.hover_on then
			@nodeinfo_widget.hovertimer.start(HOVER_TIMER)
		end
#		ap "hoverleave out"
	end
end


class TileGraphicsItemGroup < Qt::GraphicsItemGroup
	def mousePressEvent(mouseEvent)
		pos = mouseEvent.scenePos
		dlg=mouseEvent.widget.parent.parent
		case mouseEvent.button
			when Qt::LeftButton
				dlg.offset_x = pos.x / 256.0
				dlg.offset_y = pos.y / 256.0
				dlg.movemap(dlg.node)
#			when Qt::RightButton
			
		end # case
	end
end


class Qt::GraphicsSvgItem
	attr_accessor :baseElement

	def contextMenuEvent(contextEvent)
		dlg=contextEvent.widget.parent.parent
		entries=["Add Waypoint as last", "Add Waypoint at"]
		menu=Qt::Menu.new
		entries.each{|e|
			menu.addAction(e)
		}
		sel=menu.exec(contextEvent.screenPos)
		sel=sel.text if !sel.nil?

		ok = Qt::Boolean.new(true)

		case sel
			when entries[1]
				# don't put this into a thread, it will create nasty core-dumps
				resp = Qt::InputDialog.getInt(dlg, "Enter Waypoint Position.", "After which waypoint shall I insert this one?\nEnter 0 to insert at beginning.", 0, 0, 9999, 1, ok)
		end #case
		
		if ok.value then
			Thread.new {
				case sel
					when entries[0]
						dlg.writeFlightsim("set /autopilot/route-manager/input @INSERT-1:#{baseElement.shortName}")

					when entries[1]
						dlg.writeFlightsim("set /autopilot/route-manager/input @INSERT+#{resp}:#{baseElement.shortName}")
				end #case
			}
		end
	end
end

