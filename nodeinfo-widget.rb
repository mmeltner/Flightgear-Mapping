=begin
** Form generated from reading ui file 'nodeinfo-widget.ui'
**
** Created: Fr. Jun 11 14:41:10 2010
**      by: Qt User Interface Compiler version 4.6.2
**
** WARNING! All changes made in this file will be lost when recompiling ui file!
=end

class Ui_NodeinfoWidget
    attr_reader :gridLayout_3
    attr_reader :frame
    attr_reader :gridLayout_2
    attr_reader :gridLayout
    attr_reader :label_4
    attr_reader :lBalt
    attr_reader :label_3
    attr_reader :lBspeed
    attr_reader :label_6
    attr_reader :lBlat
    attr_reader :label_5
    attr_reader :lBlon

    def setupUi(nodeinfoWidget)
    if nodeinfoWidget.objectName.nil?
        nodeinfoWidget.objectName = "nodeinfoWidget"
    end
    nodeinfoWidget.resize(146, 58)
    @sizePolicy = Qt::SizePolicy.new(Qt::SizePolicy::MinimumExpanding, Qt::SizePolicy::MinimumExpanding)
    @sizePolicy.setHorizontalStretch(0)
    @sizePolicy.setVerticalStretch(0)
    @sizePolicy.heightForWidth = nodeinfoWidget.sizePolicy.hasHeightForWidth
    nodeinfoWidget.sizePolicy = @sizePolicy
    @palette = Qt::Palette.new
    brush = Qt::Brush.new(Qt::Color.new(255, 255, 255, 0))
    brush.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Active, Qt::Palette::Base, brush)
    brush1 = Qt::Brush.new(Qt::Color.new(224, 223, 222, 200))
    brush1.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Active, Qt::Palette::Window, brush1)
    @palette.setBrush(Qt::Palette::Inactive, Qt::Palette::Base, brush)
    brush2 = Qt::Brush.new(Qt::Color.new(224, 223, 222, 100))
    brush2.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Inactive, Qt::Palette::Window, brush2)
    @palette.setBrush(Qt::Palette::Disabled, Qt::Palette::Base, brush2)
    @palette.setBrush(Qt::Palette::Disabled, Qt::Palette::Window, brush2)
    nodeinfoWidget.palette = @palette
    @gridLayout_3 = Qt::GridLayout.new(nodeinfoWidget)
    @gridLayout_3.margin = 1
    @gridLayout_3.objectName = "gridLayout_3"
    @frame = Qt::Frame.new(nodeinfoWidget)
    @frame.objectName = "frame"
    @frame.frameShape = Qt::Frame::StyledPanel
    @frame.frameShadow = Qt::Frame::Raised
    @gridLayout_2 = Qt::GridLayout.new(@frame)
    @gridLayout_2.margin = 1
    @gridLayout_2.objectName = "gridLayout_2"
    @gridLayout = Qt::GridLayout.new()
    @gridLayout.objectName = "gridLayout"
    @label_4 = Qt::Label.new(@frame)
    @label_4.objectName = "label_4"
    @font = Qt::Font.new
    @font.pointSize = 7
    @label_4.font = @font

    @gridLayout.addWidget(@label_4, 0, 0, 1, 1)

    @lBalt = Qt::Label.new(@frame)
    @lBalt.objectName = "lBalt"
    @lBalt.font = @font
    @lBalt.frameShape = Qt::Frame::Panel
    @lBalt.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBalt, 0, 1, 1, 1)

    @label_3 = Qt::Label.new(@frame)
    @label_3.objectName = "label_3"
    @label_3.font = @font

    @gridLayout.addWidget(@label_3, 0, 2, 1, 1)

    @lBspeed = Qt::Label.new(@frame)
    @lBspeed.objectName = "lBspeed"
    @lBspeed.font = @font
    @lBspeed.frameShape = Qt::Frame::Panel
    @lBspeed.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBspeed, 0, 3, 1, 1)

    @label_6 = Qt::Label.new(@frame)
    @label_6.objectName = "label_6"
    @label_6.font = @font

    @gridLayout.addWidget(@label_6, 1, 0, 1, 1)

    @lBlat = Qt::Label.new(@frame)
    @lBlat.objectName = "lBlat"
    @lBlat.font = @font
    @lBlat.frameShape = Qt::Frame::Panel
    @lBlat.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBlat, 1, 1, 1, 1)

    @label_5 = Qt::Label.new(@frame)
    @label_5.objectName = "label_5"
    @label_5.font = @font

    @gridLayout.addWidget(@label_5, 1, 2, 1, 1)

    @lBlon = Qt::Label.new(@frame)
    @lBlon.objectName = "lBlon"
    @lBlon.font = @font
    @lBlon.frameShape = Qt::Frame::Panel
    @lBlon.frameShadow = Qt::Frame::Sunken

    @gridLayout.addWidget(@lBlon, 1, 3, 1, 1)


    @gridLayout_2.addLayout(@gridLayout, 0, 0, 1, 1)


    @gridLayout_3.addWidget(@frame, 0, 0, 1, 1)


    retranslateUi(nodeinfoWidget)

    Qt::MetaObject.connectSlotsByName(nodeinfoWidget)
    end # setupUi

    def setup_ui(nodeinfoWidget)
        setupUi(nodeinfoWidget)
    end

    def retranslateUi(nodeinfoWidget)
    nodeinfoWidget.windowTitle = Qt::Application.translate("NodeinfoWidget", "Form", nil, Qt::Application::UnicodeUTF8)
    @label_4.text = Qt::Application.translate("NodeinfoWidget", "Alt:", nil, Qt::Application::UnicodeUTF8)
    @label_3.text = Qt::Application.translate("NodeinfoWidget", "Speed", nil, Qt::Application::UnicodeUTF8)
    @label_6.text = Qt::Application.translate("NodeinfoWidget", "Lat:", nil, Qt::Application::UnicodeUTF8)
    @label_5.text = Qt::Application.translate("NodeinfoWidget", "Lon:", nil, Qt::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(nodeinfoWidget)
        retranslateUi(nodeinfoWidget)
    end

end

module Ui
    class NodeinfoWidget < Ui_NodeinfoWidget
    end
end  # module Ui

