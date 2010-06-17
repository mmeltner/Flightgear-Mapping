SPEED_AVG_TIME_SEC = 10 # time in sec over which the speed is being averaged

class Float
	def rad
		return self / 180.0 * Math::PI
	end
end


class Node
	attr_reader :xtile, :ytile, :lat, :lon, :elevation, :timestamp, :speed
	attr_writer :lat, :lon, :elevation, :speed

	@@zoom=15
		
	def initialize(id, time, lon, lat, elevation=0, zoom=nil)
		@id = id
		if time.kind_of? String then
			#2009-06-18T20:32:16Z
			time =~ /(\d*)-(\d*)-(\d*)T(\d*):(\d*):(\d*)Z(\d*)/
			@timestamp = Time.local($1,$2,$3,$4,$5,$6,$7)
		else
			@timestamp = time
		end
		@lon = lon
		@lat = lat
		@elevation = elevation
		
		if !zoom.nil? then
			@@zoom = zoom
		end
		@xtile = toxtile
		@ytile = toytile
#		puts "Tiles: #{@xtile},#{@ytile}"
		@speed = 0
	end
		
	def zoom(zoomlevel)
		@@zoom = zoomlevel
		@xtile = toxtile
		@ytile = toytile
	end

	def tofilename(cx=@xtile, cy=@ytile)
		return $MAPSHOME + "/#{@@zoom}/#{cx.to_i}/#{cy.to_i}"
	end
	
	def getLatLonBox(size, offset_x, offset_y)
		x = (size.width / 256 + 1) / 2
		y = (size.height / 256 + 1) / 2
		# add halve a tile at the borders to get to the border of each tile, not its center
		return [[tolon(@xtile + offset_x - x - 0.5), tolon(@xtile + offset_x + x + 0.5)],
				[tolat(@ytile + offset_y + y + 0.5), tolat(@ytile + offset_y - y - 0.5)]]
	end
	
	def getfilenames(size, offset_x, offset_y)
		fn=[]
		x = (size.width / 256 + 1) / 2 
		y = (size.height / 256 + 1) / 2 
		(-x..x).each {|ix|
			cx = @xtile + ix + offset_x
			cx = 2 ** @@zoom - 1 if cx < 0
			cx = 0 if cx > 2 ** @@zoom - 1
			(-y..y).each {|iy|
				cy = @ytile + iy + offset_y
				cy = 2 ** @@zoom - 1 if cy < 0
				cy = 0 if cy > 2 ** @@zoom - 1
				fn << tofilename(cx,cy)
			}
		}
		return fn
	end
	
	def xtile=(setto) 
		@xtile = setto
		@lon = tolon(setto)
	end
		
	def ytile=(setto)
		@ytile = setto
		@lat = tolat(setto)
	end 
	
	def tolon(setto) 
		n = 2 ** @@zoom
		return (setto / n * 360.0 - 180.0)
	end
		
	def tolat(setto)
		n = 2 ** @@zoom
		d = Math::PI - 2*Math::PI * setto / n
		return (180.0 / Math::PI * Math.atan(0.5 * (Math::exp(d) - Math::exp(-d))))
	end 
	
	def toxtile()
		n = 2 ** @@zoom
		return ((@lon + 180.0) / 360.0) * n
	end

	def toytile()
		lat_rad = @lat/180.0 * Math::PI
		n = 2 ** @@zoom
		return (1.0 - (Math::log(Math::tan(lat_rad) + (1.0 / Math::cos(lat_rad))) / Math::PI)) / 2 * n
	end
	
	def toGPStime()
		#2009-06-18T20:32:16Z
		return @timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")
	end

	def distanceto(lon, lat)
		lon1 = lon.rad
		lat1 = lat.rad
		lon2 = @lon.rad
		lat2 = @lat.rad
		begin
			return(Math.acos(Math.sin(lat1) * Math.sin(lat2) + Math.cos(lat1) * Math.cos(lat2) * Math.cos(lon2 - lon1)) * 6371000)
		rescue Errno::EDOM
			return 0
		end
	end

	def distanceto_str(lon, lat)
		d = distanceto(lon, lat)
		if d < 2000 then
			return ("%.1f" % d) + "m"
		else
			return ("%.1f" % (d/1000.0)) + "km"
		end
	end

end


class Way
	attr_reader :nodes, :currentwp, :color, :path
	attr_writer :currentwp, :path
	
	def initialize(id, user, time, color)
		@id = id
		@user = user
		@color = color
		if time.kind_of? String then
			#2009-06-18T20:32:16Z
			time =~ /(\d*)-(\d*)-(\d*)T(\d*):(\d*):(\d*)Z/
			@timestamp = Time.local($1,$2,$3,$4,$5,$6)
		else
			@timestamp = time
		end
		@nodes=[]
		@currentwp=nil
		@distance_result=Hash.new(0)
	end
	
	def <<(node)
		i=@nodes.index(nil)
		if i.nil? then
			@nodes << node
			# fetch last 10 elements
			check_nodes = @nodes[-10, 10]
			if check_nodes.nil? then
				check_nodes = @nodes
			end
			avg_nodes = check_nodes.find_all{|n|
				(node.timestamp - n.timestamp) <= SPEED_AVG_TIME_SEC
			}
			speeds=[]
			t_diff = 0.0
			avg_nodes.each_with_index{|n, i|
				if i>0 then
					t_diff = n.timestamp - avg_nodes[i-1].timestamp
					if t_diff > 0.0 then
						speeds << n.distanceto(avg_nodes[i-1].lon, avg_nodes[i-1].lat) / t_diff
					end
				end
			}
			if speeds.length > 0 then
				avg_speed = speeds.inject(0){ |result, element| result + element } / speeds.length * 3.6
			else
				avg_speed = 0.0
			end
			node.speed = avg_speed
			@nodes.length
		else
			@nodes[i]=node
			i+1
		end
	end
	
	def del(lon,lat)
		diff=[]
		@nodes.each{|n|
			diff << [ Math::sqrt((n.lat - lat) ** 2 + (n.lon - lon) ** 2) , n.lat, n.lon] if !n.nil?
		}
		mindist=999.0
		min=nil
		diff.each{|i|
			if i[0] < mindist then
				mindist = i[0]
				min=i
			end
		}
		deleted=nil
		@nodes.each_index {|i|
			if (!@nodes[i].nil?) and (@nodes[i].lat == min[1]) and (@nodes[i].lon == min[2]) then
				@nodes[i]=nil
				deleted=i
			end
		}
		return deleted+1
	end
	
	def toGPStime()
		#2009-06-18T20:32:16Z
		return @timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")
	end
 
 		if @distance_result.empty? then
			distancenode=nil
			total_distance=0.0
			@nodes.each{|n|
				if distancenode.nil? then distancenode = n; end
				d = n.distanceto(distancenode.lon, distancenode.lat)
				if  d >= 1.0 then # ignore if smaller than 1 meter
					total_distance += d
					distancenode = n
				end
				@distance_result[n] = total_distance
			}
  		end
		return @distance_result[n]
	end

end
