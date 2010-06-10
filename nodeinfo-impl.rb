require "nodeinfo-widget"
begin
	require "ap"
rescue LoadError
	def ap(*k)
		p k
	end
end

# Class MainDlg ############################################
class NodeinfoWidget < Qt::Widget
	slots "hoverTimer()"
	attr_reader :w, :hovertimer, :hover_on, :hover_widget_pos
	attr_writer :hover_on, :hover_widget_pos
	
	def initialize parent=nil
		super()
		@w=Ui::NodeinfoWidget.new
		@w.setupUi(self)
		@parent=parent

		@hovertimer = Qt::Timer.new()
		@hovertimer.setSingleShot(true)
		Qt::Object.connect( @hovertimer, SIGNAL('timeout()'), self, SLOT('hoverTimer()') )

		@hover_on=false
		@hover_widget_pos=nil
	end

	def hoverTimer()
		p "timer fired"
		if @hover_on then
			@parent.scene.items.each {|item|
				if item.kind_of? Qt::GraphicsRectItem then
					if item == @parent then
						item.setVisible(false)
						break
					end
				end
				}
			@hover_widget_pos = nil
			@hover_on = false
		end
		p "timer fired out"
	end
end
