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
require "main-dlg"
require "tile"
require "resources"
require 'socket'
require "hud-impl"
require "nodeinfo-impl"
require 'navaid.rb'
require "xml"
begin
	require "ap"
rescue LoadError
	def ap(*k)
		p k
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
Z_VALUE_TRACK = 1
Z_VALUE_TRACK_COLORED = 2
Z_VALUE_WAYPOINT = 3
Z_VALUE_NAV = 4
Z_VALUE_ORIGIN = 5
Z_VALUE_ROSE = 6
Z_VALUE_POINTERTOORIGIN = 7
Z_VALUE_POINTER = 8
Z_VALUE_HUD = 10
SCALE_SVG = 0.3

COLORRANGE_DEG = 120.0
COLOROFFSET_DEG = 240.0

MINSPEED = 0.3 # minimum speed required for heading marker to appear, in m/s
FS_READ_INTERVAL = 100 # enter GUI refresh loop every 100ms
TICKSTOSKIP = 20
AUTOSAVE_INTERVAL = 10 * 60 * 1000 # autosave interval for tracks
HOVER_TIMER = 2000 # time until HUD widget disappears
MAXVORSTODISPLAY = 500 # maximum number of nav-aids to display on map
MAXILSTODISPLAY = 200

FS_PORT = 2948


#LATSTARTUP = 49.462126667
#LONSTARTUP = 11.121691667
LATSTARTUP = 50.0368400387281
LONSTARTUP = 8.55965957641601

MAPSDIR = ENV['HOME'] + "/.OpenstreetmapTiles"

#GC.disable

# Class MainDlg ############################################
class MainDlg < Qt::Widget
	attr_reader :node, :scene_tiles, :scene, :toffset_x, :offset_y, :menu, :waypoints, \
		:flag, :zoom, :mytracks, :mytrack_current, :w
	attr_writer :node, :scene_tiles, :offset_x, :offset_y, :waypoints, :mytrack_current, :w
	attr_accessor :metricUnit
	
	slots "pBexit_clicked()", "pBdo_clicked()", "pBplus_clicked()", "pBminus_clicked()", \
		"cBpointorigin_clicked()", "pBrecordTrack_toggled(bool)", "wakeupTimer()", "autosaveTimer()", \
		'cBvor_clicked()', 'cBndb_clicked()', 'cBrw_clicked()'

	def initialize(parent, arg)
		super(parent)
		@w=Ui::MainDlg.new
		@w.setupUi(self)
		@parent=parent

		@cfg=Qt::Settings.new("MMeltnerSoft", "fg_map")
		@metricUnit = @cfg.value("metricUnit",Qt::Variant.new(true)).toBool
		@zoom = @cfg.value("zoom",Qt::Variant.new(13)).toInt
		@lat = @cfg.value("lat",Qt::Variant.new(LATSTARTUP)).toDouble
		@lon = @cfg.value("lon",Qt::Variant.new(LONSTARTUP)).toDouble
		@w.cBrw.setChecked(@cfg.value("rwChecked",Qt::Variant.new(false)).toBool)
		@w.cBndb.setChecked(@cfg.value("nbdChecked",Qt::Variant.new(false)).toBool)
		@w.cBvor.setChecked(@cfg.value("vorChecked",Qt::Variant.new(true)).toBool)

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

		@node = Node.new(1, Time.now, @lon, @lat, 0, @zoom)
		@rot = 0
		@remainingTiles = 0
		@httpThreads = Array.new
		
		@navs = Navaid.new(arg)
		
		@httpMutex = Mutex.new
		@queryMutex = Mutex.new
			
		@scene=Qt::GraphicsScene.new()
		@w.gVmap.setScene(@scene)
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
	end

	def get_data(path)
		r=@fs_ans.detect do |f|
			f.include?(path)
		end
		r =~ /-?\d+\.\d+/
		return $&.to_f
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
		
			doc = XML::Document.new()
			doc.root = XML::Node.new('gpx')
			doc.root["xmlns"] = "http://www.topografix.com/GPX/1/1"
			doc.root["creator"] = "ruby-tracker"
			doc.root["version"] = "1.1"
			doc.root["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance" 
			doc.root["xsi:schemaLocation"] = "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"

			tracknode = XML::Node.new("trk")
			doc.root << tracknode
			items.each{|track|
				segnode = XML::Node.new("trkseg")
				tracknode << segnode
				track.nodes.each{|n|
					trackpoint = XML::Node.new("trkpt")
					trackpoint["lat"] = 	n.lat.to_s.gsub(",",".")
					trackpoint["lon"] = 	n.lon.to_s.gsub(",",".")
					trackpoint << XML::Node.new("ele", n.elevation.to_s.gsub(",","."))
					trackpoint << XML::Node.new("time", n.toGPStime)
					trackpoint << XML::Node.new("time_us", n.timestamp.usec)
					segnode << trackpoint
				}
			}
			File.open($MAPSHOME + "/tracks/" + items.first.nodes.first.toGPStime + ".gpx", "w+"){|f|
				f.puts doc.inspect
			}
		end
	end
	
	def loadtrack(title)	
		fn=Qt::FileDialog::getOpenFileName(nil, title, $MAPSHOME + "/tracks/", "Track-Data (*.gpx *.log);;All (*)")
		if !fn.nil? then
			success = false
			doc = XML::Document.file(fn)
			doc.find('/ns:gpx/ns:trk', "ns:http://www.topografix.com/GPX/1/1").each{|trk|
				@mytrack_current -= 1
				trk.find("ns:trkseg", "ns:http://www.topografix.com/GPX/1/1").each{|seg|
					ns = XML::Namespace.new(seg, 'ns', 'http://www.topografix.com/GPX/1/1')
					seg.namespaces.namespace=ns
					@mytrack_current += 1
					if @mytracks[@mytrack_current].nil? then
						@mytracks[@mytrack_current] = Way.new(1, 'user', Time.now, nextcolor)
						@prev_track_node = nil
					end
					track=@mytracks[@mytrack_current]
					track.nodes.clear
					xpat_time = XML::XPath::Expression.new("ns:time")
					xpat_time_us = XML::XPath::Expression.new("ns:time_us")
					xpat_elevation = XML::XPath::Expression.new("ns:ele")
					seg.find("ns:trkpt", "ns:http://www.topografix.com/GPX/1/1").each{|tpt|
						usec = tpt.find_first(xpat_time_us)
						usec = (usec.nil? ? "0" : usec.content)
						track << Node.new(nil, tpt.find_first(xpat_time).content + usec, \
								tpt["lon"].to_f, tpt["lat"].to_f, tpt.find_first(xpat_elevation).content.to_f)
						success = true
					}
				}
			}
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
			doc = XML::Document.file(fn)
			@waypoints = Way.new(nil,'user', Time.now, "Blue")
			doc.find("/ns:gpx/ns:wpt", "ns:http://www.topografix.com/GPX/1/1").each{ |wpt|
				ns = XML::Namespace.new(wpt, 'ns', 'http://www.topografix.com/GPX/1/1')
				wpt.namespaces.namespace = ns
				xpat_time = XML::XPath::Expression.new("ns:time")
				xpat_elevation = XML::XPath::Expression.new("ns:ele")
				@waypoints << Node.new(nil, wpt.find_first(xpat_time).content, wpt["lon"].to_f, \
							wpt["lat"].to_f, wpt.find_first(xpat_elevation).content.to_f)
				success = true
			}
			if success then
				movemap(@node, true)
			else
				Qt::MessageBox::warning(nil, "Warning", "No data found in file.")
			end
			return success
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
		
			doc = XML::Document.new()
			doc.root = XML::Node.new('gpx')
			doc.root["xmlns"] = "http://www.topografix.com/GPX/1/1"
			doc.root["creator"] = "ruby-tracker"
			doc.root["version"] = "1.1"
			doc.root["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance" 
			doc.root["xsi:schemaLocation"] = "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"

			waypoints[0].nodes.each{|n|
				if !n.nil? then
					wpnode = XML::Node.new("wpt")
					doc.root << wpnode
					wpnode["lat"] = 	n.lat.to_s.gsub(",",".")
					wpnode["lon"] = 	n.lon.to_s.gsub(",",".")
					wpnode << XML::Node.new("ele", n.elevation.to_s.gsub(",","."))
					wpnode << XML::Node.new("time", n.toGPStime)
				end
			}
			fn=Qt::FileDialog::getSaveFileName(nil, "Save Waypoint File", $MAPSHOME + "/waypoints/", "Waypoint-Data (*.gpx *.log);;All (*)","*.gpx")

			if !fn.nil? then
				if fn !~ /\.gpx$/ then
					fn += ".gpx"
				end
				File.open(fn, "w+"){|f|
					f.puts doc.inspect
				}
			end
		end
	end
	
	def zoomplus
		@httpThreads.each do |th|
			th.kill
		end
		@httpThreads = Array.new
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

	def addTileToScene(f, origin_x, origin_y)
		pmi=TileGraphicsPixmapItem.new(Qt::Pixmap.new(f))
		@scene_tiles << f
		f =~ /\/(\d*)\/(\d*)\/(\d*)/
		x = $2.to_i
		y = $3.to_i
#		p x - origin_x,y - origin_y
		pmi.setOffset((x - origin_x)*256, (y - origin_y)*256)
		pmi.setZValue(Z_VALUE_TILES)
		@scene.addItem(pmi)
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
			@scene.clear
			# 8 : 256 = 2**8
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
			@scene.clear
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
			@scene.clear
		end

		fn = node.getfilenames(@w.gVmap.size, @offset_x, @offset_y)

		fn.each{|f|
			if !@scene_tiles.include?(f)
				if FileTest.exist?(f+".png") then
					addTileToScene(f, origin_x, origin_y)
				elsif downloadTiles and (@timeNoInternet.nil? or (Time.now - @timeNoInternet) > 60) then
#					Thread.abort_on_exception = true
					@httpThreads << Thread.new {
						@remainingTiles += 1
						@httpMutex.synchronize {
							h = Net::HTTP.new('tile.openstreetmap.org')
							h.open_timeout = 10
							@warningText = Qt::GraphicsSimpleTextItem.new("#{@remainingTiles} remaining tiles")
							@warningText.setBrush(Qt::Brush.new(Qt::Color.new("red")))
							@scene.addItem(@warningText)
							fontInfo = Qt::FontInfo.new(@warningText.font)
							@warningText.setPos(@w.gVmap.mapToScene((@w.gVmap.size.width - @warningText.boundingRect.width)/2, 
										@w.gVmap.size.height - fontInfo.pixelSize - 10))

							f =~ /\/\d+\/\d+\/\d+$/
							f = $&
							begin
								resp, data = h.get(f + ".png", nil)
								if resp.kind_of?(Net::HTTPOK) then
									maindir = Dir.pwd
									Dir.chdir($MAPSHOME)
									f.split("/")[0..-2].each do |dir|
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
									File.open($MAPSHOME + f + ".png", "w") do |file|
										file.write(data)
									end
									addTileToScene($MAPSHOME + f, origin_x, origin_y)
								else
									puts "Could not download tile. Internet connection alive?"
									@timeNoInternet=Time.now
								end
							# NoMethodError because of bug, see http://redmine.ruby-lang.org/issues/show/2708
							rescue NoMethodError, Errno::ECONNREFUSED, SocketError, Timeout::Error
								puts "Could not download tile. Internet connection alive?"
								@timeNoInternet=Time.now
							end
							@scene.removeItem(@warningText)
						}
						@remainingTiles -= 1
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

	def wakeupTimer()
#		p "wakeup in"
		# have to do centering every time as QT will not scroll to scene coordinates which have no elements placed there yet
		begin
			@w.gVmap.centerOn(@offset_x*256,@offset_y*256)
		rescue ArgumentError
			# swallow
		end

		@wakeupCounter += 1
		return if @wakeupCounter <= TICKSTOSKIP
		@wakeupCounter = 0

		if @fs_socket.nil? then
			begin
				@fs_socket = TCPSocket.open('localhost', FS_PORT)
				movemap(@node, true)
			rescue
				#swallow all errors
				puts "Non-critical socket error: #{$!}"
			end
		else
			begin
				@queryMutex.synchronize {
					@fs_queries.each do |q|
						@fs_socket.print("get " + q + "\r\n")
						s=""
						while select([@fs_socket], nil, nil, 0.3) do
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
			else # rescue
				#ap @fs_ans
				if @fs_ans.length>0 then # check if any answer has been received yet.
					if !@hud.nil? then
						@posnode.lon = get_data("/position/longitude-deg")
						@posnode.lat = get_data("/position/latitude-deg")
						@rot = get_data("/orientation/heading-deg")
						@alt = get_data("/position/altitude-ft")
						speed = get_data("/velocities/groundspeed-kt") * 1.852
						# protect against bug in Flightsim, speed ofter zero if returned
						@speed = speed if speed > 0
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
							@mytracks[@mytrack_current] << Node.new(nil, Time.now, @posnode.lon, @posnode.lat, @alt)
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
			end # rescue
			@fs_ans=[]
		end # socket nil
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

	def resize(*k)
		super
		@hud.setPos(@w.gVmap.mapToScene(0,0)) if !@hud.nil?
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

		# store these elements in permanent arry
		# otherwise GC will remove them and then causes core-dump in QT
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


class TileGraphicsPixmapItem < Qt::GraphicsPixmapItem
	def mousePressEvent(mouseEvent)
		pos = mouseEvent.scenePos
		dlg=mouseEvent.widget.parent.parent
		case mouseEvent.button
			when Qt::LeftButton
				dlg.offset_x = pos.x / 256.0
				dlg.offset_y = pos.y / 256.0
				dlg.movemap(dlg.node)
			when Qt::RightButton
			
		end # case
	end
	
	def contextMenuEvent(contextEvent)
		dlg=contextEvent.widget.parent.parent
		entries=["Set Waypoint", "Delete Waypoint", "Waypoints to Route-Mgr", "Set Origin", "-", "Save Waypoints", "Save Track", "Load Waypoints",
				"Load Track", ["Metric Units", dlg.metricUnit]]
		menu=Qt::Menu.new
		entries.each{|e|
			if e.kind_of? Array then
				action = Qt::Action.new(e[0], nil)
				action.setCheckable(true)
				action.setChecked(e[1])
				menu.addAction(action)
			else
				if e=="-" then
					menu.addSeparator
				else
					action = Qt::Action.new(e, nil)
					if e =~ /(Delete Waypoint|Waypoints to)/ then
						action.setEnabled(false) if dlg.waypoints.nodes.empty?
					end
					menu.addAction(action)
				end
			end
		}
		sel=menu.exec(contextEvent.screenPos)
		sel=sel.text if !sel.nil?
		lon=dlg.node.tolon(dlg.node.xtile + contextEvent.scenePos.x / 256.0)
		lat=dlg.node.tolat(dlg.node.ytile + contextEvent.scenePos.y / 256.0)
		case sel
			when entries[0]
				i=dlg.waypoints << Node.new(nil, Time.now, lon, lat)
				dlg.putflag(contextEvent.scenePos.x, contextEvent.scenePos.y, i, dlg.waypoints.nodes.last)
				if i==1 and dlg.waypoints.nodes.length == 1 then
					dlg.w.lBcurrentwp.text="1"
					dlg.waypoints.currentwp=1
				end
				
			when entries[1]
				d=dlg.waypoints.del(lon,lat)
				if dlg.w.lBcurrentwp.text.to_i == d then
					dlg.w.lBcurrentwp.text="-"
				end
				dlg.movemap(dlg.node, true)
				
			when entries[2]
				Thread.new {
					dlg.waypoints.nodes.each do |n|
						dlg.writeFlightsim("set /autopilot/route-manager/input @INSERT-1:#{n.lon.to_s.gsub(",",".")},#{n.lat.to_s.gsub(",",".")}")
					end
				}
		

			when entries[3]
				dlg.node = Node.new(1, Time.now, lon, lat)
				dlg.offset_x = 0
				dlg.offset_y = 0
				dlg.movemap(dlg.node, true)
				
			when entries[5]
				dlg.saveWaypoints([dlg.waypoints])
				
			when entries[6]
				dlg.savetrack(dlg.mytracks)

			when entries[7]
				savecurrent = dlg.waypoints.currentwp
				if dlg.loadwaypoint("Load Waypoints") then
					dlg.waypoints.currentwp = nil
				else
					dlg.waypoints.currentwp = savecurrent
				end
				
			when entries[8]
				dlg.mytrack_current += (dlg.w.pBrecordTrack.isChecked ? 0 : 1)
				savewp=dlg.mytracks[dlg.mytrack_current]
				if dlg.mytracks[dlg.mytrack_current].nil? then
					dlg.mytracks[dlg.mytrack_current] = Way.new(1, 'user', Time.now, dlg.nextcolor)
					@prev_track_node = nil
				end
				if dlg.loadtrack("Load Track") then
					dlg.w.pBrecordTrack.text = "Record Track #{dlg.mytrack_current + 2}"
					dlg.w.pBrecordTrack.setChecked(false)
				else
					dlg.mytracks[dlg.mytrack_current]=savewp
				end

			when entries[9][0]
				dlg.metricUnit = !dlg.metricUnit
								
		end #case
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

