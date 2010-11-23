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

class TileGraphicsItemGroup < Qt::GraphicsItemGroup
	def contextMenuEvent(contextEvent)
		dlg=contextEvent.widget.parent.parent
		# list of menu entries
		# if it is itself an array then it is a checkbox menu entry and the 2nd item in this array is its boolean
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
				# if array entry is "-" then just display a separator to make it more nice
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
		
		# now the selected item is handled, order is the same as defined in the array "entries" previously
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
