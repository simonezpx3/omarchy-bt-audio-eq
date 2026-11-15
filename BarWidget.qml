import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "simonez.btquality"

  property alias anchorButton: button
  property bool opened: false
  property bool busy: false
  property string currentQuality: "mq"
  property string currentLabel: "MQ"
  property bool qualityConfigurable: true
  property var qualityOptions: []
  property string qualityNote: ""
  property var rateOptions: []
  property int activeRate: 48000
  property string deviceName: ""
  property string activeProfile: ""
  property var adapters: []
  property var codecs: []
  property string lastError: ""
  property var autoeqResults: []
  property bool autoeqSearching: false
  property var eqState: ({
    enabled: false,
    preset: "Flat",
    autoeq: "",
    bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  })
  property var telemetry: ({
    codec: "",
    sample: "",
    liveQuality: "",
    volume: -1,
    muted: false,
    streamState: "",
    quant: 0,
    rate: 0,
    busy: "",
    xruns: 0,
    usbPower: "",
    usbStatus: "",
    adapterHw: ""
  })

  readonly property string scriptPath: Qt.resolvedUrl("scripts/bt_ldac_quality.py").toString().replace(/^file:\/\//, "")

  function safeTooltipText(val, maxLen) {
    const limit = maxLen || 80;
    return String(val || "").replace(/[<>&\r\n]/g, "").slice(0, limit);
  }

  function applyStatus(rawText) {
    try {
      const data = JSON.parse(rawText);
      if (data.quality !== undefined) root.currentQuality = String(data.quality);
      if (data.label) root.currentLabel = String(data.label);
      root.qualityConfigurable = (data.qualityConfigurable !== undefined) ? Boolean(data.qualityConfigurable) : true;
      root.qualityOptions = data.qualityOptions ? data.qualityOptions : [];
      root.qualityNote = data.qualityNote ? String(data.qualityNote) : "";
      root.rateOptions = data.rateOptions ? data.rateOptions : [];
      if (data.activeRate !== undefined) root.activeRate = Number(data.activeRate);
      root.deviceName = data.device ? String(data.device) : "";
      root.activeProfile = data.profile ? String(data.profile) : "";
      root.adapters = data.adapters ? data.adapters : [];
      root.codecs = data.codecs ? data.codecs : [];
      root.lastError = data.error ? String(data.error) : "";
      if (data.telemetry) {
        root.telemetry = data.telemetry;
      }
      if (data.eq) {
        root.eqState = data.eq;
      }
    } catch (e) {
      root.lastError = "Invalid status response";
    }
  }

  function refresh() {
    if (statusProc.running || setProc.running) return;
    statusProc.command = ["python3", "-B", root.scriptPath, "get"];
    statusProc.running = true;
  }

  function setQuality(mode) {
    if (setProc.running) return;
    root.busy = true;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "set", String(mode)];
    setProc.running = true;
  }

  function setCodec(profileName) {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "codec-set", String(profileName)];
    setProc.running = true;
  }

  function setSampleRate(hz) {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "rate-set", String(hz)];
    setProc.running = true;
  }

  function setAdapter(hciName) {
    if (setProc.running) return;
    root.busy = true;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "adapter-set", String(hciName)];
    setProc.running = true;
  }

  function setAdapterPower(hciName, enabled) {
    if (setProc.running) return;
    root.busy = true;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "adapter-power", String(hciName), enabled ? "on" : "off"];
    setProc.running = true;
  }

  function toggleEq() {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "eq-toggle"];
    setProc.running = true;
  }

  function setEqPreset(name) {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "eq-preset", String(name)];
    setProc.running = true;
  }

  function adjustEqBand(idx, delta) {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "eq-band", String(idx), String(delta)];
    setProc.running = true;
  }

  function setEqBandValue(idx, val) {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "eq-set", String(idx), String(val)];
    setProc.running = true;
  }

  function saveCustomEq() {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "eq-save-custom"];
    setProc.running = true;
  }

  function resetCustomEq() {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "eq-reset-custom"];
    setProc.running = true;
  }

  function searchAutoEq(query) {
    if (autoeqSearchProc.running) return;
    root.autoeqSearching = true;
    root.lastError = "";
    autoeqSearchProc.command = ["python3", "-B", root.scriptPath, "autoeq-search", String(query)];
    autoeqSearchProc.running = true;
  }

  function applyAutoEq(relPath, label) {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "autoeq-apply", String(relPath), String(label)];
    setProc.running = true;
  }

  function toggleAutoEq() {
    if (setProc.running) return;
    root.lastError = "";
    setProc.command = ["python3", "-B", root.scriptPath, "autoeq-toggle"];
    setProc.running = true;
  }

  function open() {
    root.opened = true;
    root.refresh();
    if (panelLoader.item) {
      panelLoader.item.open();
    }
  }

  function close() {
    if (panelLoader.item) {
      panelLoader.item.close();
    }
    root.opened = false;
  }

  function toggle() {
    if (root.opened) {
      root.close();
    } else {
      root.open();
    }
  }

  function togglePanel() {
    root.toggle();
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) {
      panelLoader.item.closeForPopoutSwitch();
    }
    root.opened = false;
  }

  function injectPanel() {
    const target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          root.applyStatus(text.trim());
        }
      }
    }
  }

  Process {
    id: setProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.busy = false;
        if (text && text.trim().length > 0) {
          root.applyStatus(text.trim());
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        root.busy = false;
        if (text && text.trim().length > 0 && root.lastError.length === 0) {
          root.lastError = text.trim();
        }
      }
    }
  }

  Process {
    id: autoeqSearchProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.autoeqSearching = false;
        try {
          const data = JSON.parse(text.trim());
          root.autoeqResults = data.results ? data.results : [];
          if (data.error) root.lastError = String(data.error);
        } catch (e) {
          root.lastError = "Invalid AutoEq search response";
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        root.autoeqSearching = false;
      }
    }
  }

  Timer {
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: subscribeDebounce
    interval: 250
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: pactlRestartTimer
    interval: 2000
    repeat: false
    onTriggered: {
      if (!pactlSubscribeProc.running) pactlSubscribeProc.running = true;
    }
  }

  Process {
    id: pactlSubscribeProc
    command: ["pactl", "subscribe"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        if (line.indexOf("on card") !== -1 || line.indexOf("on sink") !== -1) {
          subscribeDebounce.restart();
        }
      }
    }
    onExited: pactlRestartTimer.restart()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: {
      const xruns = (root.telemetry && root.telemetry.xruns > 0) ? ("!" + root.telemetry.xruns) : "";
      const c = (root.telemetry && root.telemetry.codec) ? root.telemetry.codec : "LDAC";
      if (root.busy) return (root.bar && root.bar.vertical) ? "..." : (c + " ...");
      if (!root.qualityConfigurable) {
        return c + (xruns ? (" " + xruns) : "");
      }
      if (root.bar && root.bar.vertical) return root.currentLabel + xruns;
      return c + " " + root.currentLabel + (xruns ? (" " + xruns) : "");
    }
    labelVisible: true
    keepSpace: true
    hasVisualContent: true
    active: root.opened
    horizontalMargin: 8.5

    tooltipText: {
      const codec = root.safeTooltipText((root.telemetry && root.telemetry.codec) ? root.telemetry.codec : "LDAC", 24);
      if (!root.deviceName) {
        const sysDev = root.safeTooltipText((root.telemetry && root.telemetry.systemDevice) ? root.telemetry.systemDevice : "System Audio", 64);
        const sample = root.safeTooltipText((root.telemetry && root.telemetry.sample) ? root.telemetry.sample : "", 32);
        return sysDev + "\n" + codec + (sample ? (" · " + sample) : "") + "\nLeft click: Open panel · Right click: Refresh";
      }
      const dev = root.safeTooltipText(root.deviceName, 48) + " (" + root.safeTooltipText(root.activeProfile || "no profile", 24) + ")";
      const liveQ = root.safeTooltipText((root.telemetry && root.telemetry.liveQuality) ? root.telemetry.liveQuality.toUpperCase() : "?", 16);
      const xruns = root.telemetry ? (root.telemetry.xruns || 0) : 0;
      const qInfo = root.qualityConfigurable ? ("Conf: " + root.safeTooltipText(root.currentLabel, 16)) : root.safeTooltipText(root.qualityNote || "Fixed profile", 40);
      return "Bluetooth " + codec + " // " + qInfo + " · Live: " + liveQ + "\n" + dev + " · ERR: " + xruns + "\nLeft click: Switch quality · Right click: Refresh";
    }

    onPressed: function(btn) {
      if (btn === Qt.RightButton || btn === 3) {
        root.refresh();
      } else {
        root.togglePanel();
      }
    }
  }

  Loader {
    id: panelLoader
    active: root.opened
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      if (root.opened && panelLoader.item) {
        panelLoader.item.open();
      }
    }
  }

  Component.onCompleted: root.refresh()
}
