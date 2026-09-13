import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "zakarch.borders"
  property var anchorItem: null
  property var hostWidget: null
  readonly property var service: localService
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real optionWidth: Style.space(68)
  readonly property real optionHeight: Style.space(26)

  Service {
    id: localService
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    iconComponent: borderIcon
    slotSize: Style.bar.iconSlot
    tooltipText: "Border Studio"
    onPressed: function(b) { root.toggle() }
  }

  Component {
    id: borderIcon
    Item {
      anchors.fill: parent
      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(1)
        radius: Style.space(4)
        color: "transparent"
        border.width: Style.space(2)
        border.color: root.service ? Model.palettes[root.service.paletteIndex].active[0] : root.foreground
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(5)
        radius: Style.space(2)
        color: "transparent"
        border.width: Style.space(1)
        border.color: root.service ? Model.palettes[root.service.paletteIndex].active[1] : root.foreground
      }
      Rectangle {
        width: Style.space(3)
        height: width
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)
        radius: width / 2
        color: root.service ? Model.palettes[root.service.paletteIndex].active[2] : root.foreground
      }
    }
  }

  KeyboardPanel {
    id: popup; anchorItem: button; owner: root; bar: root.bar; open: root.opened
    focusTarget: catcher; contentWidth: popup.fittedContentWidth(Style.space(420)); contentHeight: popup.fittedContentHeight(body.implicitHeight)
    PanelKeyCatcher { id: catcher; anchors.fill: parent; onCloseRequested: root.close(); onTabRequested: function(direction) { root.switchPanel(direction) }
      Column { id: body; width: parent.width; spacing: Style.space(9)
        Row { width: parent.width; spacing: Style.space(12)
          Text { text: "◇"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.display }
          Column { Text { text: "Border Studio"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { text: root.service ? root.service.status : "Window appearance"; color: Qt.darker(root.foreground, 1.4); font.family: root.fontFamily; font.pixelSize: Style.font.caption } }
        }
        PanelSeparator { foreground: root.foreground }
        PanelSectionHeader { text: "PALETTE"; foreground: root.foreground; fontFamily: root.fontFamily }
        Flow { width: parent.width; spacing: Style.space(5)
          Repeater { model: Model.palettes
            delegate: Button { required property var modelData; required property int index; width: root.optionWidth; height: root.optionHeight; horizontalPadding: Style.space(5); verticalPadding: Style.space(4); fontSize: Style.font.caption; text: modelData.name; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true; active: root.service && root.service.paletteIndex === index; onClicked: root.service.choosePalette(index)
              Rectangle { anchors.right: parent.right; anchors.rightMargin: Style.space(7); anchors.verticalCenter: parent.verticalCenter; width: Style.space(9); height: width; radius: width / 2; color: modelData.active[0] } } } }
        Toggle { width: parent.width; label: "Gradient borders"; description: "Blend three colors around the active window."; checked: root.service ? root.service.shine : false; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.service.setShine(!checked) }
        PanelSectionHeader { text: "AUTO-CYCLE PALETTES"; foreground: root.foreground; fontFamily: root.fontFamily }
        Flow { width: parent.width; spacing: Style.space(5); Repeater { model: Model.cycleSpeeds; delegate: Button { required property var modelData; width: root.optionWidth; height: root.optionHeight; horizontalPadding: Style.space(4); verticalPadding: Style.space(3); fontSize: Style.font.caption; text: modelData.name; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true; active: root.service && root.service.cycleSeconds === modelData.seconds; onClicked: root.service.setCycle(modelData.seconds) } } }
        PanelSectionHeader { text: "ROUNDING"; foreground: root.foreground; fontFamily: root.fontFamily }
        Flow { width: parent.width; spacing: Style.space(5); Repeater { model: Model.rounds; delegate: Button { required property int modelData; width: root.optionWidth; height: root.optionHeight; horizontalPadding: Style.space(4); verticalPadding: Style.space(3); fontSize: Style.font.caption; text: modelData + " px"; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true; active: root.service && root.service.rounding === modelData; onClicked: root.service.setRounding(modelData) } } }
        PanelSectionHeader { text: "BORDER SIZE"; foreground: root.foreground; fontFamily: root.fontFamily }
        Flow { width: parent.width; spacing: Style.space(5); Repeater { model: Model.borderSizes; delegate: Button { required property int modelData; width: root.optionWidth; height: root.optionHeight; horizontalPadding: Style.space(4); verticalPadding: Style.space(3); fontSize: Style.font.caption; text: modelData + " px"; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true; active: root.service && root.service.borderSize === modelData; onClicked: root.service.setBorderSize(modelData) } } }
        PanelSectionHeader { text: "WINDOW & SCREEN SPACING"; foreground: root.foreground; fontFamily: root.fontFamily }
        Flow { width: parent.width; spacing: Style.space(5); Repeater { model: Model.windowGaps; delegate: Button { required property int modelData; width: root.optionWidth; height: root.optionHeight; horizontalPadding: Style.space(4); verticalPadding: Style.space(3); fontSize: Style.font.caption; text: modelData + " px"; foreground: root.foreground; fontFamily: root.fontFamily; bordered: true; active: root.service && root.service.windowGap === modelData; onClicked: root.service.setWindowGap(modelData) } } }
        Text { width: parent.width; text: "Changes apply instantly and survive reboot."; color: Qt.darker(root.foreground, 1.55); font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
      }
    }
  }
}
