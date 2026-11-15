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
      visible: cqRoot.hostWidget && cqRoot.hostWidget.rateOptions && cqRoot.hostWidget.rateOptions.length > 1
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

    ColumnLayout {
      visible: cqRoot.hostWidget && cqRoot.hostWidget.adapters && cqRoot.hostWidget.adapters.length >= 2
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        text: "ADAPTER"
        textFormat: Text.PlainText
        color: Qt.rgba(cqRoot.foreground.r, cqRoot.foreground.g, cqRoot.foreground.b, 0.55)
        font.family: cqRoot.uiFont
        font.pixelSize: Style.font.xs
        font.bold: true
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Repeater {
          model: (cqRoot.hostWidget && cqRoot.hostWidget.adapters) ? cqRoot.hostWidget.adapters : []
          delegate: RowLayout {
            id: adapterItem
            required property var modelData
            readonly property bool isAdapterActive: Boolean(modelData.active)
            readonly property bool isAdapterPowered: Boolean(modelData.powered)
            readonly property bool isAdapterBusy: cqRoot.hostWidget && cqRoot.hostWidget.busy

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: Style.space(4)

            CursorSurface {
              id: adapterPill
              Layout.fillWidth: true
              implicitWidth: adapterTxt.implicitWidth + Style.space(12)
              implicitHeight: Math.max(adapterTxt.implicitHeight + Style.space(8), Style.space(26))
              current: adapterItem.isAdapterActive
              hasCursor: adapterMouse.containsMouse
              bordered: true
              foreground: cqRoot.foreground
              accent: cqRoot.accent
              opacity: !adapterItem.isAdapterPowered ? 0.5 : ((adapterItem.modelData.paired || adapterItem.isAdapterActive) ? 1.0 : 0.72)

              Text {
                id: adapterTxt
                anchors.centerIn: parent
                text: adapterItem.modelData.label + (adapterItem.modelData.paired || adapterItem.isAdapterActive ? "" : " *")
                textFormat: Text.PlainText
                maximumLineCount: 1
                color: adapterItem.isAdapterActive ? cqRoot.accent : cqRoot.foreground
                font.family: cqRoot.uiFont
                font.pixelSize: Style.font.caption
                font.bold: adapterItem.isAdapterActive
              }

              MouseArea {
                id: adapterMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !adapterItem.isAdapterBusy && adapterItem.isAdapterPowered
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (cqRoot.hostWidget) cqRoot.hostWidget.setAdapter(adapterItem.modelData.hci);
                }
              }
            }

            CursorSurface {
              id: adapterPowerPill
              implicitWidth: adapterPowerRow.implicitWidth + Style.space(12)
              implicitHeight: adapterPill.implicitHeight
              current: adapterItem.isAdapterPowered
              hasCursor: powerMouse.containsMouse
              bordered: true
              foreground: cqRoot.foreground
              accent: cqRoot.accent

              Row {
                id: adapterPowerRow
                anchors.centerIn: parent
                spacing: Style.space(5)

                Rectangle {
                  width: 8
                  height: 8
                  radius: 4
                  anchors.verticalCenter: parent.verticalCenter
                  color: adapterItem.isAdapterPowered ? "#98e28c" : "#f7768e"
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: adapterItem.isAdapterPowered ? "ON" : "OFF"
                  textFormat: Text.PlainText
                  maximumLineCount: 1
                  color: adapterItem.isAdapterPowered ? cqRoot.accent : Qt.rgba(cqRoot.foreground.r, cqRoot.foreground.g, cqRoot.foreground.b, 0.7)
                  font.family: cqRoot.uiFont
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !adapterItem.isAdapterBusy
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.WaitCursor
                onClicked: {
                  if (cqRoot.hostWidget) {
                    cqRoot.hostWidget.setAdapterPower(adapterItem.modelData.hci, !adapterItem.isAdapterPowered);
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  
}
