import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: cqRoot
  required property var hostWidget
  required property var tel
  required property var modes
  required property bool qualityConfigurable
  required property string qualityNote
  required property color foreground
  required property color accent
  required property string uiFont
  Layout.fillWidth: true
  spacing: Style.space(10)

  // 2. CODEC SELECTOR
  ColumnLayout {
    visible: cqRoot.hostWidget && cqRoot.hostWidget.codecs && cqRoot.hostWidget.codecs.length > 0
    Layout.fillWidth: true
    spacing: Style.space(6)
  
    Text {
      text: "CODEC"
      textFormat: Text.PlainText
      color: Qt.rgba(cqRoot.foreground.r, cqRoot.foreground.g, cqRoot.foreground.b, 0.55)
      font.family: cqRoot.uiFont
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
    }
  
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)
  
      Repeater {
        model: (cqRoot.hostWidget && cqRoot.hostWidget.codecs) ? cqRoot.hostWidget.codecs : []
        delegate: CursorSurface {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: codecTxt.implicitHeight + Style.space(8)
          current: modelData.active === true
          hasCursor: codecMouse.containsMouse
          bordered: true
          foreground: cqRoot.foreground
          accent: cqRoot.accent
  
          Text {
            id: codecTxt
            anchors.centerIn: parent
            text: modelData.label
            textFormat: Text.PlainText
            color: modelData.active ? cqRoot.accent : cqRoot.foreground
            font.family: cqRoot.uiFont
            font.pixelSize: Style.font.caption
            font.bold: modelData.active === true
          }
  
          MouseArea {
            id: codecMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (cqRoot.hostWidget) cqRoot.hostWidget.setCodec(modelData.profile);
            }
          }
        }
      }
    }
  }
  
  // 3. QUALITY PILLS (dynamic per active codec)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(6)
  
    Text {
      text: "QUALITY"
      textFormat: Text.PlainText
      color: Qt.rgba(cqRoot.foreground.r, cqRoot.foreground.g, cqRoot.foreground.b, 0.55)
      font.family: cqRoot.uiFont
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
    }
  
    Text {
      visible: !cqRoot.qualityConfigurable
      Layout.fillWidth: true
      text: cqRoot.qualityNote
      textFormat: Text.PlainText
      color: Qt.rgba(cqRoot.foreground.r, cqRoot.foreground.g, cqRoot.foreground.b, 0.6)
      font.family: cqRoot.uiFont
      font.pixelSize: Style.font.bodySmall
    }
  
    RowLayout {
      visible: cqRoot.qualityConfigurable
      Layout.fillWidth: true
      spacing: Style.space(6)
  
      Repeater {
        model: cqRoot.modes
        delegate: CursorSurface {
          required property var modelData
          readonly property bool isSelected: cqRoot.hostWidget && cqRoot.hostWidget.currentQuality === modelData.key
          readonly property bool isBusy: cqRoot.hostWidget && cqRoot.hostWidget.busy
  
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          implicitWidth: pillRow.implicitWidth + Style.space(10)
          implicitHeight: pillRow.implicitHeight + Style.space(12)
          current: isSelected
          hasCursor: pillMouse.containsMouse
          bordered: true
          foreground: cqRoot.foreground
          accent: cqRoot.accent
  
          Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Style.space(4)
  
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.title
              textFormat: Text.PlainText
              maximumLineCount: 1
              color: isSelected ? cqRoot.accent : cqRoot.foreground
              font.family: cqRoot.uiFont
              font.pixelSize: Style.font.bodySmall
              font.bold: isSelected
            }
  
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.sub
              textFormat: Text.PlainText
              maximumLineCount: 1
              color: Qt.rgba(cqRoot.foreground.r, cqRoot.foreground.g, cqRoot.foreground.b, 0.6)
              font.family: cqRoot.uiFont
              font.pixelSize: Style.font.caption
            }
          }
  
          MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !isBusy
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
            onClicked: {
              if (cqRoot.hostWidget) cqRoot.hostWidget.setQuality(modelData.key);
            }
          }
        }
      }
    }
  
    RowLayout {
      visible: cqRoot.hostWidget && cqRoot.hostWidget.rateOptions && cqRoot.hostWidget.rateOptions.length > 0
      Layout.fillWidth: true
      spacing: Style.space(6)
  
      Repeater {
        model: (cqRoot.hostWidget && cqRoot.hostWidget.rateOptions) ? cqRoot.hostWidget.rateOptions : []
        delegate: CursorSurface {
          required property var modelData
          readonly property bool isRateSelected: cqRoot.hostWidget && cqRoot.hostWidget.activeRate === modelData.hz
  
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          implicitWidth: rateTxt.implicitWidth + Style.space(10)
          implicitHeight: rateTxt.implicitHeight + Style.space(6)
          current: isRateSelected
          hasCursor: rateMouse.containsMouse
          bordered: true
          foreground: cqRoot.foreground
          accent: cqRoot.accent
  
          Text {
            id: rateTxt
            anchors.centerIn: parent
            text: modelData.label
            textFormat: Text.PlainText
            maximumLineCount: 1
            color: isRateSelected ? cqRoot.accent : cqRoot.foreground
            font.family: cqRoot.uiFont
            font.pixelSize: Style.font.caption
            font.bold: isRateSelected
          }
  
          MouseArea {
            id: rateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (cqRoot.hostWidget) cqRoot.hostWidget.setSampleRate(modelData.hz);
            }
          }
        }
      }
    }
  }
  
}
