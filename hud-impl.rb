require "hud-widget"

# Class MainDlg ############################################
class HudWidget < Qt::Widget
	attr_reader :w
	
	def initialize parent=nil
		super
		@w=Ui::HudWidget.new
		@w.setupUi(self)
		@parent=parent
		
	end

	def pBexit_clicked()
		p @w.pBexit.text
		@parent.close
	end
end

