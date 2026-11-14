import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "components"

Panel {
  id: root
  moduleName: "simonez.btquality"
  ipcTarget: "simonez.btquality"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool autoeqOpen: false

  readonly property color foreground: (root.bar && root.bar.foreground) ? root.bar.foreground : Commons.Color.foreground
  readonly property color background: Commons.Color.background
  readonly property color accent: (root.bar && root.bar.accent) ? root.bar.accent : Commons.Color.accent
  readonly property color urgent: (root.bar && root.bar.urgent) ? root.bar.urgent : Commons.Color.urgent
  readonly property string uiFont: (root.bar && root.bar.fontFamily) ? root.bar.fontFamily : "sans-serif"

  readonly property var tel: (root.hostWidget && root.hostWidget.telemetry) ? root.hostWidget.telemetry : ({})
  readonly property var eq: (root.hostWidget && root.hostWidget.eqState) ? root.hostWidget.eqState : ({ enabled: false, preset: "Flat", bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] })

  readonly property var defaultModes: [
    { key: "hq", title: "HQ", sub: "990k", shortcut: "1" },
    { key: "sq", title: "SQ", sub: "660k", shortcut: "2" },
    { key: "mq", title: "MQ", sub: "330k", shortcut: "3" },
    { key: "auto", title: "Auto", sub: "Adap", shortcut: "4" }
  ]
  readonly property bool qualityConfigurable: (root.hostWidget && root.hostWidget.qualityConfigurable !== undefined) ? root.hostWidget.qualityConfigurable : true
  readonly property string qualityNote: (root.hostWidget && root.hostWidget.qualityNote) ? root.hostWidget.qualityNote : "Fixed bitrate by active profile"
  readonly property var modes: (root.hostWidget && root.hostWidget.qualityOptions && root.hostWidget.qualityOptions.length > 0) ? root.hostWidget.qualityOptions : defaultModes
  readonly property var eqLabels: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
  readonly property var eqPresets: ["Bass", "V-Shape", "Vocal", "Warm", "Flat", "Custom"]

  function open() {
    panel.open = true;
  }

  function close() {
    panel.open = false;
    if (root.hostWidget && root.hostWidget.opened) {
      root.hostWidget.opened = false;
    }
  }

  function closeForPopoutSwitch() {
    panel.popoutSwitchClosing = true;
    root.close();
  }

  readonly property bool opened: panel.open
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing

  Connections {
    target: panel
    function onOpenChanged() {
      if (!panel.open && root.hostWidget && root.hostWidget.opened) {
        root.hostWidget.opened = false;
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    centerOnBar: true
    padding: Style.spacing.popupPadding
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(6), Style.space(760))

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      spacing: Style.space(10)

      Keys.onPressed: function(event) {
        if (false) {
          if (event.key === Qt.Key_Escape) {
            eqSection.autoeqOpen = false;
            event.accepted = true;
          }
          return;
        }
        if (event.key === Qt.Key_Escape) {
          root.close();
          event.accepted = true;
        } else if (event.key === Qt.Key_1) {
          if (root.hostWidget && root.qualityConfigurable && root.modes.length > 0) root.hostWidget.setQuality(root.modes[0].key);
          event.accepted = true;
        } else if (event.key === Qt.Key_2) {
          if (root.hostWidget && root.qualityConfigurable && root.modes.length > 1) root.hostWidget.setQuality(root.modes[1].key);
          event.accepted = true;
        } else if (event.key === Qt.Key_3) {
          if (root.hostWidget && root.qualityConfigurable && root.modes.length > 2) root.hostWidget.setQuality(root.modes[2].key);
          event.accepted = true;
        } else if (event.key === Qt.Key_4) {
          if (root.hostWidget && root.qualityConfigurable && root.modes.length > 3) root.hostWidget.setQuality(root.modes[3].key);
          event.accepted = true;
        }
      }

      // 1. HERO HEADER
      Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

        Text {
          id: heroIcon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: (root.hostWidget && root.hostWidget.deviceName) ? "󰂯" : "󰓃"
          textFormat: Text.PlainText
          color: (root.hostWidget && root.hostWidget.deviceName) ? root.accent : root.foreground
          font.family: root.uiFont
          font.pixelSize: Style.font.display
        }

        RowLayout {
          id: heroActions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          ToggleSwitch {
            id: eqPowerSwitch
            checked: root.eq.enabled
            foreground: root.foreground
            Layout.alignment: Qt.AlignVCenter
            onToggled: {
              if (root.hostWidget) root.hostWidget.toggleEq();
            }

            PanelToolTip {
              visible: eqPowerSwitch.containsMouse
              text: root.eq.enabled ? "Disable 10-Band EQ" : "Enable 10-Band EQ"
              fontFamily: root.uiFont
            }
          }
        }

        Column {
          id: heroLabels
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(12)
          anchors.right: heroActions.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: (root.hostWidget && root.hostWidget.deviceName) ? root.hostWidget.deviceName : ((root.tel && root.tel.systemDevice) ? root.tel.systemDevice : "System Audio")
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.uiFont
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: {
              if (root.hostWidget && root.hostWidget.busy) return "Restarting WirePlumber...";
              const codec = root.tel.codec || "LDAC";
              const sample = root.tel.sample ? root.tel.sample.replace("float32le 2ch ", "") : "48000Hz";
              const bus = (root.hostWidget && root.hostWidget.deviceName) ? (root.tel.hci ? root.tel.hci.toUpperCase() : "USB") : "ALSA";
              return codec + " · " + sample + " · " + bus;
            }
            textFormat: Text.PlainText
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.7)
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      }

      CodecQualitySection {
        hostWidget: root.hostWidget
        tel: root.tel
        modes: root.modes
        qualityConfigurable: root.qualityConfigurable
        qualityNote: root.qualityNote
        foreground: root.foreground
        accent: root.accent
        uiFont: root.uiFont
      }

      TelemetryCard {
        hostWidget: root.hostWidget
        tel: root.tel
        foreground: root.foreground
        accent: root.accent
        urgent: root.urgent
        uiFont: root.uiFont
      }

      EqSection {
        id: eqSection
        hostWidget: root.hostWidget
        eq: root.eq
        eqPresets: root.eqPresets
        eqLabels: root.eqLabels
        foreground: root.foreground
        accent: root.accent
        uiFont: root.uiFont
      }
                }
              }
            }
          }
        }
      }

      Text {
        visible: root.hostWidget && root.hostWidget.lastError.length > 0
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: root.hostWidget ? root.hostWidget.lastError : ""
        textFormat: Text.PlainText
        color: root.urgent
        font.family: root.uiFont
        font.pixelSize: Style.font.caption
      }
    }
  }
}
