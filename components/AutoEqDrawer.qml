import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

        text: parent.parent.aeqOn ? "ON" : "OFF"
        textFormat: Text.PlainText
        color: parent.parent.aeqOn ? drawerRoot.accent : Qt.rgba(drawerRoot.foreground.r, drawerRoot.foreground.g, drawerRoot.foreground.b, 0.7)
        font.family: drawerRoot.uiFont
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    MouseArea {
      id: aeqToggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (!drawerRoot.eq || !drawerRoot.eq.autoeq) {
          drawerRoot.autoeqOpen = true;
          autoeqInput.forceActiveFocus();
          return;
        }
        if (drawerRoot.hostWidget) drawerRoot.hostWidget.toggleAutoEq();
      }
    }
  }
}

BorderSurface {
  id: drawerRoot
  property bool autoeqOpen: false
  required property var hostWidget
  required property color foreground
  required property color accent
  required property string uiFont
  signal profileApplied()
  function focusSearch() { autoeqInput.forceActiveFocus(); }
  visible: drawerRoot.autoeqOpen
  Layout.fillWidth: true
  implicitHeight: autoeqCol.implicitHeight + Style.space(14)
  radius: Style.cornerRadius
  color: Qt.rgba(drawerRoot.foreground.r, drawerRoot.foreground.g, drawerRoot.foreground.b, 0.03)
  borderSpec: Border.controlSpec("normal", drawerRoot.foreground, drawerRoot.accent)

  ColumnLayout {
    id: autoeqCol
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(6)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      TextField {
        id: autoeqInput
        Layout.fillWidth: true
        placeholderText: "Wavelet / AutoEq (e.g. KZ ZEX)..."
        color: drawerRoot.foreground
        placeholderTextColor: Qt.rgba(drawerRoot.foreground.r, drawerRoot.foreground.g, drawerRoot.foreground.b, 0.45)
        font.family: drawerRoot.uiFont
        font.pixelSize: Style.font.caption
        background: Rectangle {
          radius: Style.cornerRadius
          color: Qt.rgba(drawerRoot.foreground.r, drawerRoot.foreground.g, drawerRoot.foreground.b, 0.05)
          border.width: 1
          border.color: autoeqInput.activeFocus ? drawerRoot.accent : Qt.rgba(drawerRoot.foreground.r, drawerRoot.foreground.g, drawerRoot.foreground.b, 0.14)
        }
        onAccepted: {
          if (drawerRoot.hostWidget && text.trim().length > 0) {
            drawerRoot.hostWidget.searchAutoEq(text.trim());
          }
        }
      }

      CursorSurface {
        implicitWidth: searchBtnTxt.implicitWidth + Style.space(12)
        implicitHeight: autoeqInput.implicitHeight
        hasCursor: searchBtnMouse.containsMouse
        bordered: true
        foreground: drawerRoot.foreground
        accent: drawerRoot.accent

        Text {
          id: searchBtnTxt
          anchors.centerIn: parent
          text: (drawerRoot.hostWidget && drawerRoot.hostWidget.autoeqSearching) ? "..." : "Find"
          textFormat: Text.PlainText
          color: drawerRoot.accent
          font.family: drawerRoot.uiFont
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        MouseArea {
          id: searchBtnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (drawerRoot.hostWidget && autoeqInput.text.trim().length > 0) {
              drawerRoot.hostWidget.searchAutoEq(autoeqInput.text.trim());
            }
          }
        }
      }
    }

    Repeater {
      model: (drawerRoot.hostWidget && drawerRoot.hostWidget.autoeqResults) ? drawerRoot.hostWidget.autoeqResults.slice(0, 6) : []
      delegate: CursorSurface {
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: resTxt.implicitHeight + Style.space(8)
        hasCursor: resMouse.containsMouse
        bordered: true
        foreground: drawerRoot.foreground
        accent: drawerRoot.accent

        Text {
          id: resTxt
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.space(8)
          elide: Text.ElideRight
          text: modelData.name + " · " + modelData.source
          textFormat: Text.PlainText
          color: drawerRoot.foreground
          font.family: drawerRoot.uiFont
          font.pixelSize: Style.font.caption
