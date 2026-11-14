import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// 4. 10-BAND PIPEWIRE EQ
ColumnLayout {
  id: eqRoot
  property bool autoeqOpen: false
  required property var hostWidget
  required property var eq
  required property var eqPresets
  required property var eqLabels
  required property color foreground
  required property color accent
  required property string uiFont
  function focusSearch() { autoeqDrawer.focusSearch(); }
  Layout.fillWidth: true
  spacing: Style.space(6)

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    Text {
      Layout.fillWidth: true
      text: "10-BAND EQ (±15 DB)"
      textFormat: Text.PlainText
      color: Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.55)
      font.family: eqRoot.uiFont
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
    }
  }

  // Dedicated full-width AutoEq row (search selector + ON/OFF toggle)
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(6)

    CursorSurface {
      Layout.fillWidth: true
      implicitHeight: autoeqBarRow.implicitHeight + Style.space(10)
      current: eqRoot.autoeqOpen
      hasCursor: autoeqBarMouse.containsMouse
      bordered: true
      foreground: eqRoot.foreground
      accent: eqRoot.accent

      RowLayout {
        id: autoeqBarRow
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(8)

        Text {
          text: "AutoEq"
          textFormat: Text.PlainText
          color: Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.65)
          font.family: eqRoot.uiFont
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          text: (eqRoot.eq && eqRoot.eq.autoeq) ? eqRoot.eq.autoeq : "Select headphones..."
          textFormat: Text.PlainText
          color: (eqRoot.eq.enabled && eqRoot.eq.autoeqActive) ? eqRoot.accent : eqRoot.foreground
          font.family: eqRoot.uiFont
          font.pixelSize: Style.font.caption
          font.bold: (eqRoot.eq.enabled && eqRoot.eq.autoeqActive)
        }

        Text {
          text: eqRoot.autoeqOpen ? "▴" : "▾"
          textFormat: Text.PlainText
          color: eqRoot.autoeqOpen ? eqRoot.accent : Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.55)
          font.family: eqRoot.uiFont
          font.pixelSize: Style.font.caption
        }
      }

      MouseArea {
        id: autoeqBarMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          eqRoot.autoeqOpen = !eqRoot.autoeqOpen;
          if (eqRoot.autoeqOpen) {
            eqRoot.focusSearch();
          }
        }
      }
    }

    CursorSurface {
      readonly property bool aeqOn: Boolean(eqRoot.eq.enabled && eqRoot.eq.autoeqActive)
      implicitWidth: aeqToggleRow.implicitWidth + Style.space(14)
      implicitHeight: autoeqBarRow.implicitHeight + Style.space(10)
      current: aeqOn
      hasCursor: aeqToggleMouse.containsMouse
      bordered: true
      foreground: eqRoot.foreground
      accent: eqRoot.accent

      Row {
        id: aeqToggleRow
        anchors.centerIn: parent
        spacing: Style.space(5)

        Rectangle {
          width: 8
          height: 8
          radius: 4
          anchors.verticalCenter: parent.verticalCenter
          color: parent.parent.aeqOn ? "#98e28c" : "#f7768e"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
  AutoEqDrawer {
    id: autoeqDrawer
    autoeqOpen: eqRoot.autoeqOpen
    hostWidget: eqRoot.hostWidget
    foreground: eqRoot.foreground
    accent: eqRoot.accent
    uiFont: eqRoot.uiFont
    onProfileApplied: eqRoot.autoeqOpen = false
  }

          }

          MouseArea {
            id: resMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (eqRoot.hostWidget) {
                eqRoot.hostWidget.applyAutoEq(modelData.path, modelData.name + " (" + modelData.source + ")");
                eqRoot.autoeqOpen = false;
              }
            }
          }
        }
      }
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 3
    rowSpacing: Style.space(6)
    columnSpacing: Style.space(6)

    Repeater {
      model: eqRoot.eqPresets
      delegate: CursorSurface {
        required property string modelData
        readonly property bool isPreset: eqRoot.eq.enabled && eqRoot.eq.preset === modelData

        Layout.fillWidth: true
        implicitHeight: presetTxt.implicitHeight + Style.space(8)
        current: isPreset
        hasCursor: presetMouse.containsMouse
        bordered: true
        foreground: eqRoot.foreground
        accent: eqRoot.accent

        Text {
          id: presetTxt
          anchors.centerIn: parent
          text: modelData
          textFormat: Text.PlainText
          color: isPreset ? eqRoot.accent : eqRoot.foreground
          font.family: eqRoot.uiFont
          font.pixelSize: Style.font.caption
          font.bold: isPreset
        }

        MouseArea {
          id: presetMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (eqRoot.hostWidget) eqRoot.hostWidget.setEqPreset(modelData);
          }
        }

        Item {
          visible: modelData === "Custom" && isPreset
          anchors.right: parent.right
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(20)
          height: parent.height

          Text {
            id: customResetIcon
            anchors.centerIn: parent
            text: "󰑐"
            textFormat: Text.PlainText
            color: customResetMouse.containsMouse ? eqRoot.accent : Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.7)
            font.family: eqRoot.uiFont
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            transformOrigin: Item.Center

            RotationAnimator {
              id: customResetSpinner
              target: customResetIcon
              from: 0
              to: 360
              duration: 600
              running: false
            }
          }

          MouseArea {
            id: customResetMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              customResetSpinner.restart();
              if (eqRoot.hostWidget) eqRoot.hostWidget.resetCustomEq();
            }
          }
        }
      }
    }
  }

  BorderSurface {
    Layout.fillWidth: true
    implicitHeight: eqRow.implicitHeight + Style.space(14)
    radius: Style.cornerRadius
    color: Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.03)
    borderSpec: Border.controlSpec("normal", eqRoot.foreground, eqRoot.accent)

    RowLayout {
      id: eqRow
      anchors.fill: parent
      anchors.margins: Style.space(8)
      spacing: 2

      Repeater {
        model: 10
        delegate: ColumnLayout {
          id: bandCol
          required property int index
          readonly property real externalVal: (eqRoot.eq.bands && eqRoot.eq.bands.length > index) ? Number(eqRoot.eq.bands[index]) : 0
          Layout.fillWidth: true
          spacing: Style.space(4)

          Timer {
            id: eqDebounce
            interval: 60
            repeat: false
            onTriggered: {
              if (eqRoot.hostWidget) {
                eqRoot.hostWidget.setEqBandValue(bandCol.index, bandSlider.value);
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: (bandSlider.value > 0 ? "+" : "") + bandSlider.value.toFixed(1)
            textFormat: Text.PlainText
            color: bandSlider.value !== 0 && eqRoot.eq.enabled ? eqRoot.accent : Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.75)
            font.family: eqRoot.uiFont
            font.pixelSize: Style.font.caption
            font.bold: bandSlider.value !== 0
          }

          Slider {
            id: bandSlider
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 112
            Layout.preferredWidth: 24
            orientation: Qt.Vertical
            from: -15
            to: 15
            stepSize: 0.5
            value: bandCol.externalVal

            Connections {
              target: bandCol
              function onExternalValChanged() {
                if (!bandSlider.pressed && Math.abs(bandSlider.value - bandCol.externalVal) > 0.01) {
                  bandSlider.value = bandCol.externalVal;
                }
              }
            }

            onMoved: eqDebounce.restart()

            background: Rectangle {
              x: bandSlider.leftPadding + bandSlider.availableWidth / 2 - width / 2
              y: bandSlider.topPadding
              width: 4
              height: bandSlider.availableHeight
              radius: 2
              color: Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.14)

              Rectangle {
                width: parent.width
                height: 1
                y: parent.height / 2
                color: Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.35)
              }

              Rectangle {
                width: parent.width
                y: bandSlider.value >= 0
                  ? (bandSlider.visualPosition * parent.height)
                  : (parent.height / 2)
                height: Math.abs(bandSlider.visualPosition * parent.height - parent.height / 2)
                radius: 2
                color: eqRoot.eq.enabled ? eqRoot.accent : Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.4)
              }
            }

            handle: Rectangle {
              x: bandSlider.leftPadding + bandSlider.availableWidth / 2 - width / 2
              y: bandSlider.topPadding + bandSlider.visualPosition * (bandSlider.availableHeight - height)
              width: 12
              height: 12
              radius: 6
              color: bandSlider.pressed ? eqRoot.accent : eqRoot.foreground
              border.width: 1
              border.color: eqRoot.background
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: eqRoot.eqLabels[index]
            textFormat: Text.PlainText
            color: Qt.rgba(eqRoot.foreground.r, eqRoot.foreground.g, eqRoot.foreground.b, 0.55)
            font.family: eqRoot.uiFont
            font.pixelSize: Style.font.caption
