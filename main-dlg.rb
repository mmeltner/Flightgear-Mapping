=begin
** Form generated from reading ui file 'main-dlg.ui'
**
** Created: So. Jun 6 17:44:03 2010
**      by: Qt User Interface Compiler version 4.6.2
**
** WARNING! All changes made in this file will be lost when recompiling ui file!
=end

class Ui_MainDlg
    attr_reader :horizontalLayout_3
    attr_reader :verticalLayout
    attr_reader :pBrecordTrack
    attr_reader :cBautocenter
    attr_reader :cBtoorigin
    attr_reader :cBvor
    attr_reader :cBndb
    attr_reader :cBrw
    attr_reader :fRcurrentwp
    attr_reader :gridLayout
    attr_reader :label_2
    attr_reader :lBcurrentwp
    attr_reader :verticalSpacer
    attr_reader :horizontalLayout
    attr_reader :pBminus
    attr_reader :pBplus
    attr_reader :horizontalLayout_2
    attr_reader :label
    attr_reader :lBzoom
    attr_reader :line_2
    attr_reader :pBexit
    attr_reader :gVmap

    def setupUi(mainDlg)
    if mainDlg.objectName.nil?
        mainDlg.objectName = "mainDlg"
    end
    mainDlg.resize(588, 389)
    @horizontalLayout_3 = Qt::HBoxLayout.new(mainDlg)
    @horizontalLayout_3.objectName = "horizontalLayout_3"
    @verticalLayout = Qt::VBoxLayout.new()
    @verticalLayout.objectName = "verticalLayout"
    @pBrecordTrack = Qt::PushButton.new(mainDlg)
    @pBrecordTrack.objectName = "pBrecordTrack"
    @pBrecordTrack.checkable = true

    @verticalLayout.addWidget(@pBrecordTrack)

    @cBautocenter = Qt::CheckBox.new(mainDlg)
    @cBautocenter.objectName = "cBautocenter"

    @verticalLayout.addWidget(@cBautocenter)

    @cBtoorigin = Qt::CheckBox.new(mainDlg)
    @cBtoorigin.objectName = "cBtoorigin"

    @verticalLayout.addWidget(@cBtoorigin)

    @cBvor = Qt::CheckBox.new(mainDlg)
    @cBvor.objectName = "cBvor"
    @cBvor.checked = true

    @verticalLayout.addWidget(@cBvor)

    @cBndb = Qt::CheckBox.new(mainDlg)
    @cBndb.objectName = "cBndb"

    @verticalLayout.addWidget(@cBndb)

    @cBrw = Qt::CheckBox.new(mainDlg)
    @cBrw.objectName = "cBrw"

    @verticalLayout.addWidget(@cBrw)

    @fRcurrentwp = Qt::Frame.new(mainDlg)
    @fRcurrentwp.objectName = "fRcurrentwp"
    @fRcurrentwp.frameShape = Qt::Frame::StyledPanel
    @fRcurrentwp.frameShadow = Qt::Frame::Raised
    @gridLayout = Qt::GridLayout.new(@fRcurrentwp)
    @gridLayout.objectName = "gridLayout"
    @gridLayout.setContentsMargins(2, 2, 0, 0)
    @label_2 = Qt::Label.new(@fRcurrentwp)
    @label_2.objectName = "label_2"

    @gridLayout.addWidget(@label_2, 0, 0, 1, 1)

    @lBcurrentwp = Qt::Label.new(@fRcurrentwp)
    @lBcurrentwp.objectName = "lBcurrentwp"
    @sizePolicy = Qt::SizePolicy.new(Qt::SizePolicy::Preferred, Qt::SizePolicy::Preferred)
    @sizePolicy.setHorizontalStretch(1)
    @sizePolicy.setVerticalStretch(0)
    @sizePolicy.heightForWidth = @lBcurrentwp.sizePolicy.hasHeightForWidth
    @lBcurrentwp.sizePolicy = @sizePolicy

    @gridLayout.addWidget(@lBcurrentwp, 0, 1, 1, 1)


    @verticalLayout.addWidget(@fRcurrentwp)

    @verticalSpacer = Qt::SpacerItem.new(106, 28, Qt::SizePolicy::Minimum, Qt::SizePolicy::Expanding)

    @verticalLayout.addItem(@verticalSpacer)

    @horizontalLayout = Qt::HBoxLayout.new()
    @horizontalLayout.objectName = "horizontalLayout"
    @pBminus = Qt::PushButton.new(mainDlg)
    @pBminus.objectName = "pBminus"
    @sizePolicy1 = Qt::SizePolicy.new(Qt::SizePolicy::Ignored, Qt::SizePolicy::Preferred)
    @sizePolicy1.setHorizontalStretch(0)
    @sizePolicy1.setVerticalStretch(0)
    @sizePolicy1.heightForWidth = @pBminus.sizePolicy.hasHeightForWidth
    @pBminus.sizePolicy = @sizePolicy1
    @pBminus.minimumSize = Qt::Size.new(0, 32)

    @horizontalLayout.addWidget(@pBminus)

    @pBplus = Qt::PushButton.new(mainDlg)
    @pBplus.objectName = "pBplus"
    @sizePolicy1.heightForWidth = @pBplus.sizePolicy.hasHeightForWidth
    @pBplus.sizePolicy = @sizePolicy1
    @pBplus.minimumSize = Qt::Size.new(0, 32)

    @horizontalLayout.addWidget(@pBplus)


    @verticalLayout.addLayout(@horizontalLayout)

    @horizontalLayout_2 = Qt::HBoxLayout.new()
    @horizontalLayout_2.objectName = "horizontalLayout_2"
    @label = Qt::Label.new(mainDlg)
    @label.objectName = "label"

    @horizontalLayout_2.addWidget(@label)

    @lBzoom = Qt::Label.new(mainDlg)
    @lBzoom.objectName = "lBzoom"
    @sizePolicy.heightForWidth = @lBzoom.sizePolicy.hasHeightForWidth
    @lBzoom.sizePolicy = @sizePolicy

    @horizontalLayout_2.addWidget(@lBzoom)


    @verticalLayout.addLayout(@horizontalLayout_2)

    @line_2 = Qt::Frame.new(mainDlg)
    @line_2.objectName = "line_2"
    @line_2.setFrameShape(Qt::Frame::HLine)
    @line_2.setFrameShadow(Qt::Frame::Sunken)

    @verticalLayout.addWidget(@line_2)

    @pBexit = Qt::PushButton.new(mainDlg)
    @pBexit.objectName = "pBexit"

    @verticalLayout.addWidget(@pBexit)


    @horizontalLayout_3.addLayout(@verticalLayout)

    @gVmap = Qt::GraphicsView.new(mainDlg)
    @gVmap.objectName = "gVmap"
    @sizePolicy2 = Qt::SizePolicy.new(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
    @sizePolicy2.setHorizontalStretch(3)
    @sizePolicy2.setVerticalStretch(1)
    @sizePolicy2.heightForWidth = @gVmap.sizePolicy.hasHeightForWidth
    @gVmap.sizePolicy = @sizePolicy2
    @gVmap.verticalScrollBarPolicy = Qt::ScrollBarAlwaysOff
    @gVmap.horizontalScrollBarPolicy = Qt::ScrollBarAlwaysOff
    brush = Qt::Brush.new(Qt::Color.new(0, 0, 0, 0))
    brush.style = Qt::NoBrush
    @gVmap.backgroundBrush = brush
    brush1 = Qt::Brush.new(Qt::Color.new(0, 0, 0, 0))
    brush1.style = Qt::NoBrush
    @gVmap.foregroundBrush = brush1
    @gVmap.viewportUpdateMode = Qt::GraphicsView::FullViewportUpdate

    @horizontalLayout_3.addWidget(@gVmap)


    retranslateUi(mainDlg)
    Qt::Object.connect(@pBexit, SIGNAL('clicked()'), mainDlg, SLOT('pBexit_clicked()'))
    Qt::Object.connect(@cBtoorigin, SIGNAL('clicked()'), mainDlg, SLOT('cBpointorigin_clicked()'))
    Qt::Object.connect(@pBrecordTrack, SIGNAL('toggled(bool)'), mainDlg, SLOT('pBrecordTrack_toggled(bool)'))
    Qt::Object.connect(@pBplus, SIGNAL('clicked()'), mainDlg, SLOT('pBplus_clicked()'))
    Qt::Object.connect(@pBminus, SIGNAL('clicked()'), mainDlg, SLOT('pBminus_clicked()'))
    Qt::Object.connect(@cBvor, SIGNAL('toggled(bool)'), mainDlg, SLOT('cBvor_clicked()'))
    Qt::Object.connect(@cBndb, SIGNAL('toggled(bool)'), mainDlg, SLOT('cBndb_clicked()'))
    Qt::Object.connect(@cBrw, SIGNAL('toggled(bool)'), mainDlg, SLOT('cBrw_clicked()'))

    Qt::MetaObject.connectSlotsByName(mainDlg)
    end # setupUi

    def setup_ui(mainDlg)
        setupUi(mainDlg)
    end

    def retranslateUi(mainDlg)
    mainDlg.windowTitle = Qt::Application.translate("MainDlg", "Voc-Trainer", nil, Qt::Application::UnicodeUTF8)
    @pBrecordTrack.text = Qt::Application.translate("MainDlg", "Record Track 1", nil, Qt::Application::UnicodeUTF8)
    @cBautocenter.text = Qt::Application.translate("MainDlg", "Autocenter", nil, Qt::Application::UnicodeUTF8)
    @cBtoorigin.text = Qt::Application.translate("MainDlg", "Point to Origin", nil, Qt::Application::UnicodeUTF8)
    @cBvor.text = Qt::Application.translate("MainDlg", "Display VOR", nil, Qt::Application::UnicodeUTF8)
    @cBndb.text = Qt::Application.translate("MainDlg", "Display NDB", nil, Qt::Application::UnicodeUTF8)
    @cBrw.text = Qt::Application.translate("MainDlg", "Display Rws", nil, Qt::Application::UnicodeUTF8)
    @label_2.text = Qt::Application.translate("MainDlg", "Current WP: ", nil, Qt::Application::UnicodeUTF8)
    @lBcurrentwp.text = ''
    @pBminus.text = Qt::Application.translate("MainDlg", "-", nil, Qt::Application::UnicodeUTF8)
    @pBplus.text = Qt::Application.translate("MainDlg", "+", nil, Qt::Application::UnicodeUTF8)
    @label.text = Qt::Application.translate("MainDlg", "Zoom:", nil, Qt::Application::UnicodeUTF8)
    @lBzoom.text = ''
    @pBexit.text = Qt::Application.translate("MainDlg", "Exit", nil, Qt::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(mainDlg)
        retranslateUi(mainDlg)
    end

end

module Ui
    class MainDlg < Ui_MainDlg
    end
end  # module Ui

