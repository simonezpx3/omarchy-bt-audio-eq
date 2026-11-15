import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: telCard
  required property var hostWidget
  required property var tel
  required property color foreground
  required property color accent
  required property color urgent
  required property string uiFont
  Layout.fillWidth: true
  implicitHeight: telGrid.implicitHeight + Style.space(14)
  radius: Style.cornerRadius
  color: Qt.rgba(telCard.foreground.r, telCard.foreground.g, telCard.foreground.b, 0.03)
  borderSpec: Border.controlSpec("normal", telCard.foreground, telCard.accent)

  GridLayout {
    id: telGrid
    readonly property bool isBt: Boolean(telCard.hostWidget && telCard.hostWidget.deviceName)
    anchors.fill: parent
    anchors.margins: Style.space(8)
    columns: 2
    rowSpacing: Style.space(4)
    columnSpacing: Style.space(10)

    Text {
      text: telGrid.isBt ? "Live / Config" : "Output / Format"
      textFormat: Text.PlainText
      color: Qt.rgba(telCard.foreground.r, telCard.foreground.g, telCard.foreground.b, 0.55)
      font.family: telCard.uiFont
      font.pixelSize: Style.font.caption
    }
    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      text: {
        if (!telGrid.isBt) return telCard.tel.sample || "—";
        const live = telCard.tel.liveQuality ? telCard.tel.liveQuality.toUpperCase() : (telCard.tel.codec || "—");
        const conf = (telCard.hostWidget && telCard.hostWidget.qualityConfigurable) ? telCard.hostWidget.currentLabel : "Fixed";
        return live + " / " + conf;
      }
      textFormat: Text.PlainText
      color: (!telGrid.isBt) ? telCard.accent : ((telCard.tel.liveQuality && telCard.hostWidget && telCard.tel.liveQuality !== telCard.hostWidget.currentQuality) ? telCard.urgent : telCard.accent)
      font.family: telCard.uiFont
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Text {
      text: "Stream / Xruns"
      textFormat: Text.PlainText
      color: Qt.rgba(telCard.foreground.r, telCard.foreground.g, telCard.foreground.b, 0.55)
      font.family: telCard.uiFont
      font.pixelSize: Style.font.caption
    }
    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      text: {
        const st = telCard.tel.streamState === "R" ? "PLAY" : (telCard.tel.streamState === "C" ? "IDLE" : (telCard.tel.streamState === "S" ? "SUSP" : "—"));
        const q = telCard.tel.quant > 0 ? (" Q" + telCard.tel.quant) : "";
        const err = telCard.tel.xruns !== undefined ? telCard.tel.xruns : 0;
        return st + q + " · ERR " + err;
      }
      textFormat: Text.PlainText
      color: (telCard.tel.xruns > 0) ? telCard.urgent : telCard.foreground
      font.family: telCard.uiFont
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      visible: telGrid.isBt && Boolean(telCard.tel.adapterHw)
      text: "Adapter"
      textFormat: Text.PlainText
      color: Qt.rgba(telCard.foreground.r, telCard.foreground.g, telCard.foreground.b, 0.55)
      font.family: telCard.uiFont
      font.pixelSize: Style.font.caption
    }
    Text {
      visible: telGrid.isBt && Boolean(telCard.tel.adapterHw)
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      text: telCard.tel.adapterHw || "—"
      textFormat: Text.PlainText
      color: telCard.foreground
      font.family: telCard.uiFont
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      text: telGrid.isBt ? "Adapter Power" : "Volume / Mute"
      textFormat: Text.PlainText
      color: Qt.rgba(telCard.foreground.r, telCard.foreground.g, telCard.foreground.b, 0.55)
      font.family: telCard.uiFont
      font.pixelSize: Style.font.caption
    }
    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      text: {
        if (!telGrid.isBt) {
          const vol = (telCard.tel.volume !== undefined && telCard.tel.volume >= 0) ? (telCard.tel.volume + "%") : "—";
          const m = telCard.tel.muted ? "Muted" : "Active";
          return vol + " · " + m;
        }
        return (telCard.tel.usbPower || "—") + " · " + (telCard.tel.usbStatus || "—");
      }
      textFormat: Text.PlainText
      color: (telGrid.isBt && telCard.tel.usbPower === "auto") ? telCard.urgent : (telCard.tel.muted ? telCard.urgent : telCard.foreground)
      font.family: telCard.uiFont
      font.pixelSize: Style.font.bodySmall
    }
  }
}
