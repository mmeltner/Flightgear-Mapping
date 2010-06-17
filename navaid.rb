require 'zlib'
require 'bsearch'
begin
	require "ap"
rescue LoadError
	def ap(*k)
		p k
	end
end


NAVAID_FILE = "/usr/share/games/FlightGear/Navaids/nav.dat.gz"
#NAVAID_FILE = "/home/chief/dev/nav.dat.gz"

class Navaid
	Vor = Struct.new( :lat, :lon, :freq, :shortName, :longName, :type, :sceneItem )
	Runway = Struct.new( :lat, :lon, :freq, :alt, :direction, :airportName, :runwayName, :sceneItem )

	def initialize(arg=nil)
		@vors = Array.new
		@runways = Array.new
		@lonSort = Array.new
		@latSort = Array.new
		@rwlatSort = Array.new
		@rwlonSort = Array.new
		@navaidFile = NAVAID_FILE
		
		vorCount = 0
		rwCount = 0
		
		checkForNavaidFile(arg)
		
		begin
			Zlib::GzipReader.open(@navaidFile) {|gz|
				gz.each_line do |l|
					vordata=[]
					if l[0,2] == "2 " or l[0,2] == "3 " then
						vordata = l.split(" ")
						# is it a NDB?
						if l[0,2] == "2 " then
							freq = vordata[4].to_i
							type = "NDB"
						else
							# freq is in MHz * 100
							freq = vordata[4].to_i / 100.0
							type = vordata[-1]
						end
						@vors << Vor.new( vordata[1], vordata[2], freq, vordata[7], vordata[8..-2].join(" "), type, nil)
						@latSort << [vordata[1].to_f, vorCount]
						@lonSort << [vordata[2].to_f, vorCount]
						vorCount += 1
					end

					# check for runways
					if l[0,2] == "4 " then
						rwdata = l.split(" ")
						# freq is in MHz * 100
						@runways << Runway.new( rwdata[1], rwdata[2], rwdata[4].to_i / 100.0, rwdata[3].to_i, 
								rwdata[6].to_f, rwdata[8], rwdata[9], nil)
						@rwlatSort << [rwdata[1].to_f, rwCount]
						@rwlonSort << [rwdata[2].to_f, rwCount]
						rwCount += 1
					end
				end
			}

			@runways.sort! do |a,b|
				a.airportName <=> b.airportName
			end

			Zlib::GzipReader.open(@navaidFile) {|gz|
				mmdata = nil
				range = nil
				gz.each_line do |l|
					# check for MiddleMarker used for placement of cone peak
					if l[0,2] == "8 " then
						mmdata = l.split(" ")
						range = @runways.bsearch_range {|rw| rw.airportName <=> mmdata[8]}
						rwMod = @runways[range].find do |rw|
							rw.runwayName == mmdata[9]
						end
						# exchange lat and lon with position of corresponding MiddleMarker
						if !rwMod.nil? then
							rwMod.lat = mmdata[1]
							rwMod.lon = mmdata[2]
						end
					end
				end
			}


			@latSort.sort! do |a,b|
				a[0] <=> b[0]
			end
			@lonSort.sort! do |a,b|
				a[0] <=> b[0]
			end
			@rwlatSort.sort! do |a,b|
				a[0] <=> b[0]
			end
			@rwlonSort.sort! do |a,b|
				a[0] <=> b[0]
			end
		rescue Errno::ENOENT
			puts "Warning. Could not find data file for VORs."
		end
#		ap @vors
	end
	
	def checkForNavaidFile(arg)
		root = ENV['FG_ROOT']
		root = "" if root.nil?
		arg="" if arg.nil?
		paths=[ arg, root + "/Navaids", "/usr/share/games/FlightGear/Navaids", "%ProgramFiles%/FlightGear/data/Navaids" ]
		paths.each do |path|
			if FileTest.exist?(path) then
				@navaidFile = path + "/nav.dat.gz"
				puts "Found \"#{path}\" for loading navigation aids."
				break
			end
		end
	end
	
	def getVORs(box)
		i = @latSort.bsearch_lower_boundary {|x| x[0] <=> box[1][0]}
		j = @latSort.bsearch_upper_boundary {|x| x[0] <=> box[1][1]}
		latCandidates = @latSort[i...j].collect do |a|
			a[1] # return its array index
		end
		# protect against excessive CPU load
		return [] if j-i > 2000

		i = @lonSort.bsearch_lower_boundary {|x| x[0] <=> box[0][0]}
		j = @lonSort.bsearch_upper_boundary {|x| x[0] <=> box[0][1]}
		lonCandidates = @lonSort[i...j].collect do |a|
			a[1] # return its array index
		end
		# protect against excessive CPU load
		return [] if j-i > 2000
		
		cross=latCandidates.find_all do |a|
			lonCandidates.include?(a)
		end

		cross.collect do |a|
			@vors[a]
		end
	end

	def getRunways(box)
		i = @rwlatSort.bsearch_lower_boundary {|x| x[0] <=> box[1][0]}
		j = @rwlatSort.bsearch_upper_boundary {|x| x[0] <=> box[1][1]}
		latCandidates = @rwlatSort[i...j].collect do |a|
			a[1] # return its array index
		end
		# protect against excessive CPU load
		return [] if j-i > 1000

		i = @rwlonSort.bsearch_lower_boundary {|x| x[0] <=> box[0][0]}
		j = @rwlonSort.bsearch_upper_boundary {|x| x[0] <=> box[0][1]}
		lonCandidates = @rwlonSort[i...j].collect do |a|
			a[1] # return its array index
		end
		# protect against excessive CPU load
		return [] if j-i > 1000
		
		cross=latCandidates.find_all do |a|
			lonCandidates.include?(a)
		end

		cross.collect do |a|
			@runways[a]
		end
	end
end


