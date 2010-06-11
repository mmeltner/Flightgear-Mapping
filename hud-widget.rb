=begin
** Form generated from reading ui file 'hud-widget.ui'
**
** Created: Fr. Jun 11 14:41:10 2010
**      by: Qt User Interface Compiler version 4.6.2
**
** WARNING! All changes made in this file will be lost when recompiling ui file!
=end

class Ui_HudWidget
    attr_reader :verticalLayout
    attr_reader :lBspeed
    attr_reader :lBdistance
    attr_reader :gridLayout
    attr_reader :label_4
    attr_reader :lBalt
    attr_reader :label_3
    attr_reader :lBheading
    attr_reader :label_6
    attr_reader :lBlat
    attr_reader :label_5
    attr_reader :lBlon

    def setupUi(hudWidget)
    if hudWidget.objectName.nil?
        hudWidget.objectName = "hudWidget"
    end
    hudWidget.resize(161, 130)
    @sizePolicy = Qt::SizePolicy.new(Qt::SizePolicy::MinimumExpanding, Qt::SizePolicy::MinimumExpanding)
    @sizePolicy.setHorizontalStretch(0)
    @sizePolicy.setVerticalStretch(0)
    @sizePolicy.heightForWidth = hudWidget.sizePolicy.hasHeightForWidth
    hudWidget.sizePolicy = @sizePolicy
    @palette = Qt::Palette.new
    brush = Qt::Brush.new(Qt::Color.new(255, 255, 255, 255))
    brush.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Active, Qt::Palette::Base, brush)
    brush1 = Qt::Brush.new(Qt::Color.new(224, 223, 222, 100))
    brush1.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Active, Qt::Palette::Window, brush1)
    @palette.setBrush(Qt::Palette::Inactive, Qt::Palette::Base, brush)
    @palette.setBrush(Qt::Palette::Inactive, Qt::Palette::Window, brush1)
    @palette.setBrush(Qt::Palette::Disabled, Qt::Palette::Base, brush1)
    @palette.setBrush(Qt::Palette::Disabled, Qt::Palette::Window, brush1)
    hudWidget.palette = @palette
    @verticalLayout = Qt::VBoxLayout.new(hudWidget)
    @verticalLayout.objectName = "verticalLayout"
    @lBspeed = Qt::Label.new(hudWidget)
    @lBspeed.objectName = "lBspeed"
    @sizePolicy1 = Qt::SizePolicy.new(Qt::SizePolicy::Preferred, Qt::SizePolicy::MinimumExpanding)
    @sizePolicy1.setHorizontalStretch(0)
    @sizePolicy1.setVerticalStretch(0)
    @sizePolicy1.heightForWidth = @lBspeed.sizePolicy.hasHeightForWidth
    @lBspeed.sizePolicy = @sizePolicy1
    @font = Qt::Font.new
    @font.pointSize = 18
    @font.bold = true
    @font.weight = 75
    @font.styleStrategy = Qt::Font::PreferAntialias
    @lBspeed.font = @font
    @lBspeed.frameShape = Qt::Frame::Panel
    @lBspeed.frameShadow = Qt::Frame::Sunken
    @lBspeed.alignment = Qt::AlignCenter

    @verticalLayout.addWidget(@lBspeed)

    @lBdistance = Qt::Label.new(hudWidget)
    @lBdistance.objectName = "lBdistance"
    @sizePolicy1.heightForWidth = @lBdistance.sizePolicy.hasHeightForWidth
    @lBdistance.sizePolicy = @sizePolicy1
    @lBdistance.font = @font
    @lBdistance.frameShape = Qt::Frame::Panel
    @lBdistance.frameShadow = Qt::Frame::Sunken
    @lBdistance.alignment = Qt::AlignCenter

    @verticalLayout.addWidget(@lBdistance)

    @gridLayout = Qt::GridLayout.new()
    @gridLayout.objectName = "gridLayout"
    @label_4 = Qt::Label.new(hudWidget)
    @label_4.objectName = "label_4"
    @font1 = Qt::Font.new
    @font1.family = "DejaVu Sans"
    @font1.pointSize = 9
    @label_4.font = @font1

    @gridLayout.addWidget(@label_4, 0, 0, 1, 1)

    @lBalt = Qt::Label.new(hudWidget)
    @lBalt.objectName = "lBalt"
    @lBalt.font = @font1
    @lBalt.frameShape = Qt::Frame::Panel
    @lBalt.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBalt, 0, 1, 1, 1)

    @label_3 = Qt::Label.new(hudWidget)
    @label_3.objectName = "label_3"
    @label_3.font = @font1

    @gridLayout.addWidget(@label_3, 0, 2, 1, 1)

    @lBheading = Qt::Label.new(hudWidget)
    @lBheading.objectName = "lBheading"
    @lBheading.font = @font1
    @lBheading.frameShape = Qt::Frame::Panel
    @lBheading.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBheading, 0, 3, 1, 1)

    @label_6 = Qt::Label.new(hudWidget)
    @label_6.objectName = "label_6"
    @label_6.font = @font1

    @gridLayout.addWidget(@label_6, 1, 0, 1, 1)

    @lBlat = Qt::Label.new(hudWidget)
    @lBlat.objectName = "lBlat"
    @lBlat.font = @font1
    @lBlat.frameShape = Qt::Frame::Panel
    @lBlat.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBlat, 1, 1, 1, 1)

    @label_5 = Qt::Label.new(hudWidget)
    @label_5.objectName = "label_5"
    @label_5.font = @font1

    @gridLayout.addWidget(@label_5, 1, 2, 1, 1)

    @lBlon = Qt::Label.new(hudWidget)
    @lBlon.objectName = "lBlon"
    @lBlon.font = @font1
    @lBlon.frameShape = Qt::Frame::Panel
    @lBlon.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBlon, 1, 3, 1, 1)


    @verticalLayout.addLayout(@gridLayout)


    retranslateUi(hudWidget)

    Qt::MetaObject.connectSlotsByName(hudWidget)
    end # setupUi

    def setup_ui(hudWidget)
        setupUi(hudWidget)
    end

    def retranslateUi(hudWidget)
    hudWidget.windowTitle = Qt::Application.translate("HudWidget", "Form", nil, Qt::Application::UnicodeUTF8)
    @lBspeed.text = ''
    @lBdistance.text = ''
    @label_4.text = Qt::Application.translate("HudWidget", "Alt:", nil, Qt::Application::UnicodeUTF8)
    @label_3.text = Qt::Application.translate("HudWidget", "Head:", nil, Qt::Application::UnicodeUTF8)
    @label_6.text = Qt::Application.translate("HudWidget", "Lat:", nil, Qt::Application::UnicodeUTF8)
    @label_5.text = Qt::Application.translate("HudWidget", "Lon:", nil, Qt::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(hudWidget)
        retranslateUi(hudWidget)
    end

end

module Ui
    class HudWidget < Ui_HudWidget
    end
end  # module Ui

