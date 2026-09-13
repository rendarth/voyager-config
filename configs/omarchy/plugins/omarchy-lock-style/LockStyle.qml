import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons
import "LockStyleHelper.js" as LockStyleHelper
import "LockViewGenerator.js" as LockViewGenerator

BarWidget {
  id: root
  moduleName: "omarchy-lock-style"

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color bg: root.bar ? root.bar.background : Color.background
  readonly property color dim: Qt.darker(root.fg, 1.4)
  readonly property color subdim: Qt.darker(root.fg, 1.7)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + (Quickshell.env("USER") || "user"))
  readonly property string currentUsername: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "demonc"

  property bool popupOpen: false
  property string viewMode: "menu" // "menu" | "editor"
  property string currentTab: "menu" // "menu" | "position" | "clock" | "pin" | "user" | "media" | "visuals" | "wallpaper"
  property string statusMessage: ""
  property bool statusIsError: false
  property string currentBarIcon: "󰌾"

  onPopupOpenChanged: {
    if (popupOpen) {
      if (root.isBrowsing) {
        root.viewMode = "editor"
        root.currentTab = "wallpaper"
        root.isBrowsing = false
      } else {
        loadConfig()
        var powerEnabled = !root.config.menu || root.config.menu.enablePowerMenu !== false
        root.viewMode = powerEnabled ? "menu" : "editor"
      }
      root.statusMessage = ""
      checkInitialBackup()
    } else {
      if (root.isDirty && !root.isBrowsing) {
        loadConfig()
        root.isDirty = false
      }
    }
  }

  property bool openedByCommand: false
  readonly property bool opened: root.popupOpen

  function open() {
    root.openedByCommand = true
    root.popupOpen = true
  }
  function show() {
    root.openedByCommand = true
    root.popupOpen = true
  }
  function hide() { root.close() }
  function toggle() {
    if (!root.popupOpen) root.openedByCommand = true
    root.popupOpen = !root.popupOpen
  }

  // Configuration object (in-memory & reactive)
  property var config: LockStyleHelper.defaultConfig()
  property bool isDirty: false
  property bool backupExists: false
  property bool isBrowsing: false
  property string lastPickedPath: ""

  // Interactive Live Preview Simulation State
  property string previewPinInput: "12345"
  property var previewDate: new Date()
  Timer {
    interval: 500
    running: root.popupOpen
    repeat: true
    onTriggered: root.previewDate = new Date()
  }

  property real previewAnimTick: 0.0
  property real previewColonOpacity: 1.0
  property real previewBreathingScale: 1.0

  Timer {
    interval: 33
    running: root.popupOpen
    repeat: true
    onTriggered: {
      root.previewAnimTick += 0.05
      var anims = root.config.visuals ? (root.config.visuals.animations !== false) : true
      var pulse = root.config.visuals ? (root.config.visuals.pulseColon !== false && anims) : true
      var breath = root.config.visuals ? (root.config.visuals.breathingFocus !== false && anims) : true

      root.previewColonOpacity = pulse ? (0.55 + 0.45 * Math.cos(root.previewAnimTick * 1.8)) : 1.0
      root.previewBreathingScale = breath ? (1.0 + 0.035 * (0.5 + 0.5 * Math.sin(root.previewAnimTick * 1.4))) : 1.0
    }
  }

  // File paths
  readonly property string pluginDir: root.homeDir + "/.config/omarchy/plugins/omarchy-lock-style"
  readonly property string pluginLockViewPath: root.pluginDir + "/LockView.qml"
  readonly property string configDir: root.homeDir + "/.config/omarchy/lock-style"
  readonly property string wallpapersDir: root.configDir + "/wallpapers"
  readonly property string configFilePath: root.homeDir + "/.config/omarchy/lock-style.json"
  readonly property string backupFilePath: root.configDir + "/backup/LockView.original.qml"
  readonly property string currentWallpaperPath: root.homeDir + "/.local/state/omarchy/current/background"

  // System Fonts Detection
  readonly property var systemFonts: {
    var raw = Qt.fontFamilies() || []
    var filtered = []
    for (var i = 0; i < raw.length; i++) {
      var f = raw[i]
      if (f && !f.startsWith("@") && filtered.indexOf(f) === -1) {
        filtered.push(f)
      }
    }
    return filtered.sort()
  }

  // MPRIS Detection for preview & status
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var activeMprisPlayer: {
    for (var i = 0; i < mprisPlayers.length; i++) {
      if (mprisPlayers[i] && (mprisPlayers[i].isPlaying || (mprisPlayers[i].trackTitle && mprisPlayers[i].trackTitle.length > 0))) {
        return mprisPlayers[i];
      }
    }
    return null;
  }

  Component.onCompleted: {
    loadConfig()
    checkInitialBackup()
  }

  // ------------------------------------------------------------- Persistence
  FileView {
    id: configFile
    path: root.configFilePath
    watchChanges: false
    atomicWrites: true
    printErrors: false

    onLoaded: {
      var raw = typeof configFile.text === "function" ? configFile.text() : configFile.text
      if (raw && String(raw).trim().length > 0) {
        try {
          var parsed = JSON.parse(String(raw))
          root.config = LockStyleHelper.deepMerge(LockStyleHelper.defaultConfig(), parsed)
          if (root.config.menu && root.config.menu.barIcon !== undefined) {
            root.currentBarIcon = root.config.menu.barIcon
          }
          root.isDirty = false
        } catch (e) {
          console.warn("LockStyle: Error parsing lock-style.json", e)
        }
      } else {
        saveConfig()
      }
    }

    onLoadFailed: {
      saveConfig()
    }
  }

  FileView {
    id: lockViewFile
    path: root.pluginLockViewPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  function loadConfig() {
    if (configFile.path) configFile.reload()
  }

  function saveConfig() {
    try {
      var jsonStr = JSON.stringify(root.config, null, 2) + "\n"
      if (typeof configFile.setText === "function") {
        configFile.setText(jsonStr)
      }
      if (root.config.menu && root.config.menu.barIcon !== undefined) {
        root.currentBarIcon = root.config.menu.barIcon
      }
    } catch (e) {
      console.warn("LockStyle: Error saving lock-style.json", e)
    }
  }

  function updateMenuConfig(key, value) {
    var next = LockStyleHelper.deepMerge({}, root.config)
    if (!next.menu) next.menu = {}
    next.menu[key] = value
    root.config = next
    if (next.menu.barIcon !== undefined) {
      root.currentBarIcon = next.menu.barIcon
    }
    saveConfig()
    root.statusMessage = "✓ Configuration saved"
    root.statusIsError = false
  }

  function checkInitialBackup() {
    initBackupProc.running = true
  }

  Process {
    id: initBackupProc
    command: [
      "bash", "-c",
      'mkdir -p "$1" && if [ ! -f "$2" ] && [ -f "$3" ]; then cp -f "$3" "$2"; fi',
      "safe-init-backup",
      root.configDir + "/backup",
      root.backupFilePath,
      "/usr/share/omarchy/shell/plugins/lock/LockView.qml"
    ]
    onExited: function(code) {
      root.backupExists = true
    }
  }

  Process {
    id: applyProc
    onStarted: {
      root.statusMessage = "Applying lock screen style..."
      root.statusIsError = false
    }
    onExited: function(code) {
      if (code === 0) {
        root.statusMessage = "✓ Lock screen style applied successfully!"
        root.statusIsError = false
        root.isDirty = false
        root.saveConfig()
      } else {
        root.statusMessage = "✗ Error applying lock screen style"
        root.statusIsError = true
      }
    }
  }

  function applyLockStyle() {
    root.saveConfig()
    var qmlContent = LockViewGenerator.generateLockViewQml(root.config)

    if (typeof lockViewFile.setText === "function") {
      lockViewFile.setText(qmlContent)
    }

    applyProc.command = [
      "bash", "-c",
      'rm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true; omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true; (sleep 0.1; omarchy restart shell >/dev/null 2>&1 || true) &',
      "safe-apply"
    ]
    applyProc.running = true
  }

  Process {
    id: pickWallpaperProc
    command: [
      "zenity",
      "--file-selection",
      "--title=Select Lock Screen Wallpaper",
      "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.avif *.PNG *.JPG *.JPEG *.WEBP *.AVIF",
      "--file-filter=All Files | *"
    ]
    stdout: SplitParser {
      onRead: function(line) {
        var path = String(line).trim()
        if (path && path.length > 0) {
          root.lastPickedPath = path
        }
      }
    }
    onExited: function(code) {
      var picked = root.lastPickedPath.trim()
      root.lastPickedPath = ""

      if (picked) {
        root.saveCustomWallpaper(picked)
      } else {
        root.viewMode = "editor"
        root.currentTab = "wallpaper"
        Qt.callLater(function() { root.popupOpen = true })
      }
    }
  }

  Process {
    id: copyWallpaperProc
    property string targetDest: ""
    property string origSource: ""
    onExited: function(code) {
      if (code === 0 && copyWallpaperProc.targetDest.length > 0) {
        root.applySelectedCustomWallpaper(copyWallpaperProc.targetDest, copyWallpaperProc.origSource)
      } else {
        root.statusMessage = "✗ Error copying wallpaper"
        root.statusIsError = true
      }
      root.viewMode = "editor"
      root.currentTab = "wallpaper"
      Qt.callLater(function() { root.popupOpen = true })
    }
  }

  function saveCustomWallpaper(sourcePath) {
    if (!sourcePath) return;
    var ext = sourcePath.split('.').pop() || "jpg";
    ext = ext.replace(/[^a-zA-Z0-9]/g, "") || "jpg";
    var filename = "lock_wp_" + Date.now() + "." + ext;
    var destPath = root.wallpapersDir + "/" + filename;
    copyWallpaperProc.targetDest = destPath;
    copyWallpaperProc.origSource = sourcePath;
    copyWallpaperProc.command = [
      "bash", "-c",
      'mkdir -p "$1" && cp -f "$2" "$3"',
      "safe-copy-wallpaper",
      root.wallpapersDir,
      sourcePath,
      destPath
    ];
    copyWallpaperProc.running = true;
  }

  function applySelectedCustomWallpaper(destPath, origSource) {
    if (!root.config.wallpaper) root.config.wallpaper = {};
    root.config.wallpaper.mode = "custom";
    root.config.wallpaper.customPath = destPath;
    root.config.wallpaper.originalSourcePath = origSource || destPath;

    // History management (up to 6 items)
    var hist = (root.config.wallpaper.history || []).slice();
    hist = hist.filter(function(item) { return item && item.path !== destPath; });
    hist.unshift({
      path: destPath,
      name: destPath.split('/').pop(),
      date: new Date().toISOString().split('T')[0]
    });
    if (hist.length > 6) hist = hist.slice(0, 6);
    root.config.wallpaper.history = hist;

    root.isDirty = true;
    root.config = JSON.parse(JSON.stringify(root.config));
    root.saveConfig();
    root.statusMessage = "Wallpaper selected. Click 'Apply' to save.";
    root.statusIsError = false;
  }

  function restoreSystemWallpaper() {
    if (!root.config.wallpaper) root.config.wallpaper = {};
    root.config.wallpaper.mode = "system";
    root.config.wallpaper.customPath = "";
    root.isDirty = true;
    root.config = JSON.parse(JSON.stringify(root.config));
    root.statusMessage = "System wallpaper selected. Click 'Apply' to save.";
    root.statusIsError = false;
  }

  Process {
    id: restoreProc
    onStarted: {
      root.statusMessage = "Restoring official stock lock screen..."
      root.statusIsError = false
    }
    onExited: function(code) {
      if (code === 0) {
        root.config = LockStyleHelper.PRESETS.stock_omarchy.config
        root.saveConfig()
        root.statusMessage = "✓ Official stock lock screen restored!"
        root.statusIsError = false
        root.isDirty = false
      } else {
        root.statusMessage = "✗ Error restoring official stock lock screen"
        root.statusIsError = true
      }
    }
  }

  function restoreOriginal() {
    root.config = LockStyleHelper.PRESETS.stock_omarchy.config
    root.isDirty = false
    root.saveConfig()

    restoreProc.command = [
      "bash", "-c",
      'if [ -f "$2" ]; then cp -f "$2" "$1"; elif [ -f "$3" ]; then cp -f "$3" "$1"; fi\nrm -rf "$HOME/.cache/quickshell/qmlcache" 2>/dev/null || true\nomarchy restart shell >/dev/null 2>&1 || omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true',
      "safe-restore",
      root.pluginLockViewPath,
      root.backupFilePath,
      "/usr/share/omarchy/shell/plugins/lock/LockView.qml"
    ]
    restoreProc.running = true
  }

  function cancelChanges() {
    root.loadConfig()
    root.isDirty = false
    root.statusMessage = ""
    root.close()
  }

  function deleteSavedWallpaper(targetPath) {
    if (!targetPath) return;
    if (!root.config.wallpaper) root.config.wallpaper = {};

    var hist = (root.config.wallpaper.history || []).slice();
    hist = hist.filter(function(item) { return item && item.path !== targetPath; });
    root.config.wallpaper.history = hist;

    // If currently selected, revert to system or next available
    if (root.config.wallpaper.customPath === targetPath) {
      if (hist.length > 0) {
        root.config.wallpaper.customPath = hist[0].path;
        root.config.wallpaper.mode = "custom";
      } else {
        root.config.wallpaper.customPath = "";
        root.config.wallpaper.mode = "system";
      }
    }

    Quickshell.execDetached(["rm", "-f", targetPath]);

    root.isDirty = true;
    root.config = JSON.parse(JSON.stringify(root.config));
    root.saveConfig();
    root.statusMessage = "✓ Wallpaper deleted";
    root.statusIsError = false;
  }

  function applyPreset(presetKey) {
    if (LockStyleHelper.PRESETS[presetKey]) {
      var p = LockStyleHelper.PRESETS[presetKey]
      root.config = LockStyleHelper.deepMerge(LockStyleHelper.defaultConfig(), p.config)
      root.isDirty = true
      root.statusMessage = "Preset '" + p.name + "' loaded. Click 'Apply' to save."
      root.statusIsError = false
    }
  }

  function testLockScreen() {
    Quickshell.execDetached(["omarchy-system-lock"])
  }

  function updateConfig(section, key, value) {
    var next = LockStyleHelper.deepMerge({}, root.config)
    if (!next[section]) next[section] = {}
    next[section][key] = value
    root.config = next
    root.isDirty = true
  }

  function close() {
    if (root.isBrowsing) {
      root.popupOpen = false
      return
    }
    if (root.isDirty) {
      root.loadConfig()
      root.isDirty = false
    }
    root.popupOpen = false
  }

  readonly property bool showBarIcon: !root.config.menu || root.config.menu.showBarIcon !== false

  Process {
    id: copyCmdProc
    command: ["wl-copy", "omarchy-shell shell toggle omarchy-lock-style"]
  }

  Timer {
    id: copyFeedbackTimer
    interval: 1500
    repeat: false
  }

  // ------------------------------------------------------------- Bar Sizing & Button
  implicitWidth: showBarIcon ? barButton.implicitWidth : 0
  implicitHeight: showBarIcon ? barButton.implicitHeight : 0
  visible: showBarIcon || root.popupOpen

  BarIconButton {
    id: barButton
    anchors.fill: parent
    visible: root.showBarIcon
    bar: root.bar
    text: root.currentBarIcon
    active: root.popupOpen
    useActiveColor: root.popupOpen
    tooltipText: ""

    iconComponent: Component {
      Text {
        text: root.currentBarIcon
        color: barButton.active && barButton.useActiveColor
          ? (root.bar ? root.bar.foreground : Color.accent)
          : root.fg
        font.family: root.fontFamily
        font.pixelSize: barButton.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    onPressed: function(button) {
      root.openedByCommand = false
      root.popupOpen = !root.popupOpen
    }
  }

  // ------------------------------------------------------------- Keyboard Panel Popup
  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.popupOpen
    centerOnBar: !root.showBarIcon
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.viewMode === "menu" ? Style.space(260) : Style.space(660))
    contentHeight: panel.fittedContentHeight(root.viewMode === "menu" ? menuLayout.implicitHeight : popupLayout.implicitHeight, root.viewMode === "menu" ? Style.space(340) : Style.space(880))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      readonly property var cardItem: parent ? parent.parent : null
      readonly property bool shouldCenter: root.openedByCommand || !root.showBarIcon

      Binding {
        target: keyCatcher.cardItem
        property: "x"
        value: Math.round((panel.screenW - panel.contentWidth) / 2)
        when: keyCatcher.cardItem !== null && keyCatcher.shouldCenter
        restoreMode: Binding.RestoreBindingOrValue
      }

      Binding {
        target: keyCatcher.cardItem
        property: "y"
        value: Math.round((panel.screenH - panel.contentHeight) / 2)
        when: keyCatcher.cardItem !== null && keyCatcher.shouldCenter
        restoreMode: Binding.RestoreBindingOrValue
      }

      Keys.onEscapePressed: function(event) {
        root.close()
        event.accepted = true
      }

      // ==========================================
      // VIEW A: QUICK POWER & LOCK MENU
      // ==========================================
      Column {
        id: menuLayout
        visible: root.viewMode === "menu"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        // Menu Header with Username
        Item {
          width: parent.width
          height: menuHeaderLeft.implicitHeight

          Row {
            id: menuHeaderLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: root.currentUsername
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Top-right corner button to edit lock screen (Icon Only)
          Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰏘"
            tooltipText: "Customize Lock Screen"
            bordered: true
            foreground: Color.accent
            onClicked: root.viewMode = "editor"
          }
        }

        PanelSeparator { foreground: root.fg }

        // Session Actions List (Clean Single-Line)
        Column {
          width: parent.width
          spacing: Style.space(5)

          // 1. Lock Screen
          BorderSurface {
            width: parent.width
            implicitHeight: Style.space(36)
            radius: Style.cornerRadius
            color: mouseLock.containsMouse ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent)
            borderSpec: Border.controlSpec(mouseLock.containsMouse ? "hover-cursor" : "normal", root.fg, Color.accent)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                visible: !root.config.menu || root.config.menu.showIcons !== false
                text: ""
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Lock"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: mouseLock
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.close()
                Quickshell.execDetached(["omarchy-system-lock"])
              }
            }
          }

          // 2. Restart
          BorderSurface {
            width: parent.width
            implicitHeight: Style.space(36)
            radius: Style.cornerRadius
            color: mouseReboot.containsMouse ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent)
            borderSpec: Border.controlSpec(mouseReboot.containsMouse ? "hover-cursor" : "normal", root.fg, Color.accent)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                visible: !root.config.menu || root.config.menu.showIcons !== false
                text: "󰜉"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Restart"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: mouseReboot
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.close()
                Quickshell.execDetached(["omarchy-system-reboot"])
              }
            }
          }

          // 3. Shut Down
          BorderSurface {
            width: parent.width
            implicitHeight: Style.space(36)
            radius: Style.cornerRadius
            color: mouseShutdown.containsMouse ? Style.hoverFillFor(root.fg, Color.urgent) : Style.normalFillFor(root.fg, Color.urgent)
            borderSpec: Border.controlSpec(mouseShutdown.containsMouse ? "hover-cursor" : "normal", root.fg, Color.urgent)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                visible: !root.config.menu || root.config.menu.showIcons !== false
                text: "󰐥"
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Shut Down"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: mouseShutdown
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.close()
                Quickshell.execDetached(["omarchy-system-shutdown"])
              }
            }
          }

          // 4. Suspend
          BorderSurface {
            width: parent.width
            implicitHeight: Style.space(36)
            radius: Style.cornerRadius
            color: mouseSuspend.containsMouse ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent)
            borderSpec: Border.controlSpec(mouseSuspend.containsMouse ? "hover-cursor" : "normal", root.fg, Color.accent)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(10)

              Text {
                visible: !root.config.menu || root.config.menu.showIcons !== false
                text: "󰒲"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Suspend"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: mouseSuspend
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.close()
                Quickshell.execDetached(["systemctl", "suspend"])
              }
            }
          }
        }
      }

      // ==========================================
      // VIEW B: LOCK SCREEN CUSTOMIZER
      // ==========================================
      Column {
        id: popupLayout
        visible: root.viewMode === "editor"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ==========================================
        // 1. HEADER (With Back Button)
        // ==========================================
        Item {
          width: parent.width
          height: headerLeft.implicitHeight

          Row {
            id: headerLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Button {
              visible: !root.config.menu || root.config.menu.enablePowerMenu !== false
              iconText: "←"
              tooltipText: "Back to Menu"
              bordered: true
              onClicked: root.viewMode = "menu"
            }

            Text {
              text: "󰌾"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "Lock Screen Customizer"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            BorderSurface {
              visible: root.isDirty
              anchors.verticalCenter: parent.verticalCenter
              radius: Style.cornerRadius
              color: Style.normalFillFor(root.fg, Color.lock.borderError)
              borderSpec: Border.controlSpec("normal", root.fg, Color.lock.borderError)
              width: unsavedText.implicitWidth + Style.space(12)
              height: unsavedText.implicitHeight + Style.space(4)

              Text {
                id: unsavedText
                anchors.centerIn: parent
                text: "Unsaved"
                color: Color.lock.borderError
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // ==========================================
        // 2. LIVE REAL-TIME PREVIEW VIEWPORT (16:9 Screen Display)
        // ==========================================
        Item {
          id: previewContainer
          width: parent.width
          height: previewBox.height

          BorderSurface {
            id: previewBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - Style.space(16), Style.space(480))
            height: Math.round(width * 9 / 16)
            radius: Style.cornerRadius
            color: Color.background
            borderSpec: Border.controlSpec("normal", root.fg, Color.accent)
            clip: true

            readonly property string screenPos: (root.config.layout && root.config.layout.position) ? root.config.layout.position : "center"
            readonly property bool isLeft: screenPos === "top_left" || screenPos === "center_left" || screenPos === "bottom_left"
            readonly property bool isRight: screenPos === "top_right" || screenPos === "center_right" || screenPos === "bottom_right"
            readonly property bool isCenter: !isLeft && !isRight
            readonly property int previewMarginH: Style.space(16)
            readonly property int previewMarginV: Style.space(10)

            Image {
              id: previewBg
              anchors.fill: parent
              source: (root.config.wallpaper && root.config.wallpaper.mode === "custom" && root.config.wallpaper.customPath) ? ("file://" + root.config.wallpaper.customPath) : ("file://" + root.currentWallpaperPath)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }

            MultiEffect {
              anchors.fill: previewBg
              source: previewBg
              blurEnabled: ((root.config.wallpaper && root.config.wallpaper.blur !== undefined) ? root.config.wallpaper.blur : (root.config.visuals ? root.config.visuals.backgroundBlur : 1.0)) > 0.01
              blur: (root.config.wallpaper && root.config.wallpaper.blur !== undefined) ? root.config.wallpaper.blur : (root.config.visuals ? root.config.visuals.backgroundBlur : 1.0)
              blurMax: 64
              contrast: root.config.visuals ? root.config.visuals.contrast : -0.08
            }

            Rectangle {
              anchors.fill: parent
              color: "#000000"
              opacity: (root.config.wallpaper && root.config.wallpaper.dim !== undefined) ? root.config.wallpaper.dim : 0.22
            }

            BorderSurface {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: Style.space(8)
              radius: Style.cornerRadius
              color: Qt.rgba(0, 0, 0, 0.6)
              borderSpec: Border.controlSpec("normal", root.fg, Color.accent)
              width: liveBadgeText.implicitWidth + Style.space(10)
              height: liveBadgeText.implicitHeight + Style.space(4)

              Row {
                id: liveBadgeText
                anchors.centerIn: parent
                spacing: Style.space(4)

                Rectangle {
                  width: 6
                  height: 6
                  radius: 3
                  color: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "PREVIEW"
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(9)
                  font.bold: true
                }
              }
            }

            Column {
              id: livePreviewColumn
              spacing: Style.space(3)
              width: Math.min(previewBox.width - Style.space(36), Style.space(250))

              x: {
                if (previewBox.isLeft) return previewBox.previewMarginH;
                if (previewBox.isRight) return previewBox.width - width - previewBox.previewMarginH;
                return Math.round((previewBox.width - width) / 2);
              }

              y: {
                if (previewBox.screenPos === "top_left" || previewBox.screenPos === "top_right") {
                  return previewBox.previewMarginV;
                }
                if (previewBox.screenPos === "bottom_left" || previewBox.screenPos === "bottom_right") {
                  return Math.max(previewBox.previewMarginV, previewBox.height - implicitHeight - previewBox.previewMarginV);
                }
                return Math.round((previewBox.height - implicitHeight) / 2);
              }

              // Clock & Date (Above PIN)
              Column {
                visible: (root.config.clock && root.config.clock.enabled && (root.config.clock.position !== "below_pin")) || (root.config.date && root.config.date.enabled && (!root.config.clock || root.config.clock.position !== "below_pin" || !root.config.clock.enabled))
                width: parent.width
                spacing: Style.space(1)

                // Date (Above Clock or standalone)
                Text {
                  visible: root.config.date && root.config.date.enabled && (root.config.date.position === "above_clock" || !root.config.clock || !root.config.clock.enabled)
                  width: parent.width
                  text: LockStyleHelper.formatDatePreview(root.previewDate, root.config.date ? root.config.date.format : "")
                  font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                  font.pixelSize: Style.space(8.5)
                  font.weight: Font.Medium
                  color: root.fg
                  opacity: 0.85
                  horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                }

                // Clock (Horizontal layout)
                Row {
                  visible: root.config.clock && root.config.clock.enabled && root.config.clock.layout !== "vertical"
                  x: previewBox.isLeft ? 0 : (previewBox.isRight ? parent.width - width : Math.round((parent.width - width) / 2))
                  spacing: Style.space(2)

                  Text {
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "horizontal", root.config.clock ? root.config.clock.showAmPm : true)
                      return tf.hours || "12"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(22)
                    font.weight: Font.Bold
                    color: root.fg
                  }

                  Item {
                    implicitWidth: colonAboveText.implicitWidth
                    implicitHeight: colonAboveText.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.previewColonOpacity

                    Text {
                      id: colonAboveText
                      anchors.centerIn: parent
                      text: ":"
                      font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                      font.pixelSize: Style.space(22)
                      font.weight: Font.Bold
                      color: root.fg
                    }
                  }

                  Text {
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "horizontal", root.config.clock ? root.config.clock.showAmPm : true)
                      return tf.minutes || "00"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(22)
                    font.weight: Font.Bold
                    color: root.fg
                  }

                  Text {
                    visible: root.config.clock && root.config.clock.format === "12h" && root.config.clock.showAmPm
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, "12h", "horizontal", true)
                      return tf.ampm || "PM"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Color.accent
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(3)
                  }
                }

                // Clock (Vertical layout)
                Column {
                  visible: root.config.clock && root.config.clock.enabled && root.config.clock.layout === "vertical"
                  width: parent.width
                  spacing: 0

                  Text {
                    width: parent.width
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "vertical", false)
                      return tf.hours || "12"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(16)
                    font.weight: Font.Bold
                    color: root.fg
                    horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                  }

                  Text {
                    width: parent.width
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "vertical", false)
                      return tf.minutes || "00"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(16)
                    font.weight: Font.Bold
                    color: root.fg
                    opacity: 0.85
                    horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                  }
                }

                // Date (Below Clock)
                Text {
                  visible: root.config.date && root.config.date.enabled && (root.config.date.position === "below_clock") && root.config.clock && root.config.clock.enabled
                  width: parent.width
                  text: LockStyleHelper.formatDatePreview(root.previewDate, root.config.date ? root.config.date.format : "")
                  font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                  font.pixelSize: Style.space(8.5)
                  font.weight: Font.Medium
                  color: root.fg
                  opacity: 0.85
                  horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                }
              }

              // User Profile (Above PIN)
              Column {
                visible: root.config.user && (root.config.user.position !== "below_pin") && ((root.config.user.avatarEnabled !== false) || (root.config.user.greetingEnabled !== false) || (root.config.user.quoteEnabled === true) || (root.config.user.customText && root.config.user.customText.trim().length > 0))
                width: parent.width
                spacing: Style.space(2)

                Rectangle {
                  visible: !root.config.user || root.config.user.avatarEnabled !== false
                  x: previewBox.isLeft ? 0 : (previewBox.isRight ? parent.width - width : Math.round((parent.width - width) / 2))
                  width: Style.space(22)
                  height: Style.space(22)
                  radius: width / 2
                  color: Color.background
                  border.color: Color.accent
                  border.width: 1.2

                  Text {
                    anchors.centerIn: parent
                    text: "󰮯"
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(12)
                    color: Color.accent
                  }
                }

                Text {
                  visible: !root.config.user || root.config.user.greetingEnabled !== false
                  width: parent.width
                  text: LockStyleHelper.formatGreeting((root.config.user && root.config.user.greetingTemplate) ? root.config.user.greetingTemplate : "Welcome back, {user}", root.currentUsername)
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(9.5)
                  font.bold: true
                  color: root.fg
                  horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                }

                Text {
                  visible: root.config.user && (root.config.user.quoteEnabled === true || (root.config.user.customText && root.config.user.customText.trim().length > 0))
                  width: parent.width
                  text: (root.config.user && root.config.user.quoteEnabled === true)
                    ? "Simplicity is the soul of efficiency 🌌"
                    : ((root.config.user && root.config.user.customText) ? root.config.user.customText : "")
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  font.italic: true
                  color: root.fg
                  opacity: 0.75
                  elide: Text.ElideRight
                  horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                }
              }

              // PIN Box Preview
              BorderSurface {
                id: previewPinBox
                width: Math.min(parent.width, (root.config.pinBox ? Math.round(root.config.pinBox.width * 0.44) : 160))
                height: (root.config.pinBox && root.config.pinBox.height) ? Math.round(root.config.pinBox.height * 0.40) : Style.space(24)
                x: previewBox.isLeft ? 0 : (previewBox.isRight ? parent.width - width : Math.round((parent.width - width) / 2))
                radius: root.config.pinBox ? Math.round(root.config.pinBox.radius * 0.45) : 8
                color: Qt.rgba(Color.lock.background.r, Color.lock.background.g, Color.lock.background.b, (root.config.pinBox ? root.config.pinBox.opacity : 0.85))
                borderSpec: Border.controlSpec("active", root.fg, Color.accent)
                scale: root.previewBreathingScale

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    text: LockStyleHelper.maskPasswordText(root.previewPinInput, root.config.pinBox ? root.config.pinBox.mode : "dots")
                    font.family: root.config.clock ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: (root.config.pinBox && root.config.pinBox.fontSize) ? Math.round(root.config.pinBox.fontSize * 0.45) : Style.space(10)
                    font.letterSpacing: 1.5
                    color: Color.lock.text
                  }
                }
              }

              // Clock & Date (Below PIN)
              Column {
                visible: (root.config.clock && root.config.clock.enabled && root.config.clock.position === "below_pin") || (root.config.date && root.config.date.enabled && root.config.clock && root.config.clock.position === "below_pin")
                width: parent.width
                spacing: Style.space(1)

                // Date (Above Clock or standalone)
                Text {
                  visible: root.config.date && root.config.date.enabled && (root.config.date.position === "above_clock" || !root.config.clock || !root.config.clock.enabled)
                  width: parent.width
                  text: LockStyleHelper.formatDatePreview(root.previewDate, root.config.date ? root.config.date.format : "")
                  font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                  font.pixelSize: Style.space(8.5)
                  font.weight: Font.Medium
                  color: root.fg
                  opacity: 0.85
                  horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                }

                // Clock (Horizontal layout)
                Row {
                  visible: root.config.clock && root.config.clock.enabled && root.config.clock.layout !== "vertical"
                  x: previewBox.isLeft ? 0 : (previewBox.isRight ? parent.width - width : Math.round((parent.width - width) / 2))
                  spacing: Style.space(2)

                  Text {
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "horizontal", root.config.clock ? root.config.clock.showAmPm : true)
                      return tf.hours || "12"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(22)
                    font.weight: Font.Bold
                    color: root.fg
                  }

                  Item {
                    implicitWidth: colonBelowText.implicitWidth
                    implicitHeight: colonBelowText.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.previewColonOpacity

                    Text {
                      id: colonBelowText
                      anchors.centerIn: parent
                      text: ":"
                      font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                      font.pixelSize: Style.space(22)
                      font.weight: Font.Bold
                      color: root.fg
                    }
                  }

                  Text {
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "horizontal", root.config.clock ? root.config.clock.showAmPm : true)
                      return tf.minutes || "00"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(22)
                    font.weight: Font.Bold
                    color: root.fg
                  }

                  Text {
                    visible: root.config.clock && root.config.clock.format === "12h" && root.config.clock.showAmPm
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, "12h", "horizontal", true)
                      return tf.ampm || "PM"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Color.accent
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(3)
                  }
                }

                // Clock (Vertical layout)
                Column {
                  visible: root.config.clock && root.config.clock.enabled && root.config.clock.layout === "vertical"
                  width: parent.width
                  spacing: 0

                  Text {
                    width: parent.width
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "vertical", false)
                      return tf.hours || "12"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(16)
                    font.weight: Font.Bold
                    color: root.fg
                    horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                  }

                  Text {
                    width: parent.width
                    text: {
                      var tf = LockStyleHelper.formatTimePreview(root.previewDate, root.config.clock ? root.config.clock.format : "24h", "vertical", false)
                      return tf.minutes || "00"
                    }
                    font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                    font.pixelSize: Style.space(16)
                    font.weight: Font.Bold
                    color: root.fg
                    opacity: 0.85
                    horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                  }
                }

                // Date (Below Clock)
                Text {
                  visible: root.config.date && root.config.date.enabled && (root.config.date.position === "below_clock") && root.config.clock && root.config.clock.enabled
                  width: parent.width
                  text: LockStyleHelper.formatDatePreview(root.previewDate, root.config.date ? root.config.date.format : "")
                  font.family: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : root.fontFamily
                  font.pixelSize: Style.space(8.5)
                  font.weight: Font.Medium
                  color: root.fg
                  opacity: 0.85
                  horizontalAlignment: previewBox.isLeft ? Text.AlignLeft : (previewBox.isRight ? Text.AlignRight : Text.AlignHCenter)
                }
              }
            }

            // Bottom Media Bar Simulation
            BorderSurface {
              visible: root.config.media && root.config.media.enabled
              y: previewBox.height - height - previewBox.previewMarginV
              x: {
                var targetX = Math.round((previewBox.width - width) / 2);
                if (previewBox.screenPos === "top_left" || previewBox.screenPos === "center_left" || previewBox.screenPos === "bottom_right") {
                  targetX = previewBox.previewMarginH;
                } else if (previewBox.screenPos === "top_right" || previewBox.screenPos === "center_right" || previewBox.screenPos === "bottom_left") {
                  targetX = previewBox.width - width - previewBox.previewMarginH;
                }
                return Math.max(previewBox.previewMarginH, Math.min(previewBox.width - width - previewBox.previewMarginH, targetX));
              }
              radius: Style.cornerRadius
              color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.82)
              borderSpec: Border.controlSpec("normal", root.fg, Color.accent)
              width: Math.min(mediaSimRow.implicitWidth + Style.space(16), Style.space(200))
              height: Style.space(18)
              clip: true

              Row {
                id: mediaSimRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  text: "󰎈"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(9.5)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: root.activeMprisPlayer ? (root.activeMprisPlayer.trackTitle + " — " + root.activeMprisPlayer.trackArtist) : "Synthwave Radio — Lofi Dev Vibes"
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(8)
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, Style.space(160))
                }
              }
            }
          }
        }

        // ==========================================
        // 3. TAB SELECTION BAR
        // ==========================================
        Row {
          width: parent.width
          spacing: Style.space(4)

          Button {
            text: "Menu"
            active: root.currentTab === "menu"
            bordered: true
            foreground: root.currentTab === "menu" ? Color.accent : root.fg
            onClicked: root.currentTab = "menu"
          }

          Button {
            text: "Position"
            active: root.currentTab === "position"
            bordered: true
            foreground: root.currentTab === "position" ? Color.accent : root.fg
            onClicked: root.currentTab = "position"
          }

          Button {
            text: "Clock"
            active: root.currentTab === "clock"
            bordered: true
            foreground: root.currentTab === "clock" ? Color.accent : root.fg
            onClicked: root.currentTab = "clock"
          }

          Button {
            text: "PIN Box"
            active: root.currentTab === "pin"
            bordered: true
            foreground: root.currentTab === "pin" ? Color.accent : root.fg
            onClicked: root.currentTab = "pin"
          }

          Button {
            text: "User & Quotes"
            active: root.currentTab === "user"
            bordered: true
            foreground: root.currentTab === "user" ? Color.accent : root.fg
            onClicked: root.currentTab = "user"
          }

          Button {
            text: "Media"
            active: root.currentTab === "media"
            bordered: true
            foreground: root.currentTab === "media" ? Color.accent : root.fg
            onClicked: root.currentTab = "media"
          }

          Button {
            text: "Visuals"
            active: root.currentTab === "visuals"
            bordered: true
            foreground: root.currentTab === "visuals" ? Color.accent : root.fg
            onClicked: root.currentTab = "visuals"
          }

          Button {
            text: "Wallpaper"
            active: root.currentTab === "wallpaper"
            bordered: true
            foreground: root.currentTab === "wallpaper" ? Color.accent : root.fg
            onClicked: root.currentTab = "wallpaper"
          }
        }

        // ==========================================
        // 4. TAB PANELS
        // ==========================================
        Item {
          width: parent.width
          implicitHeight: {
            if (root.currentTab === "menu") return menuTab.implicitHeight;
            if (root.currentTab === "position") return positionTab.implicitHeight;
            if (root.currentTab === "clock") return clockTab.implicitHeight;
            if (root.currentTab === "pin") return pinTab.implicitHeight;
            if (root.currentTab === "user") return userTab.implicitHeight;
            if (root.currentTab === "media") return mediaTab.implicitHeight;
            if (root.currentTab === "visuals") return visualsTab.implicitHeight;
            if (root.currentTab === "wallpaper") return wallpaperTab.implicitHeight;
            return menuTab.implicitHeight;
          }

          // TAB 1: MENU & BAR ICON
          Column {
            id: menuTab
            visible: root.currentTab === "menu"
            width: parent.width
            spacing: Style.space(12)

            Toggle {
              width: parent.width
              checked: !root.config.menu || root.config.menu.enablePowerMenu !== false
              label: "Enable power menu"
              onClicked: root.updateMenuConfig("enablePowerMenu", !checked)
            }

            Toggle {
              width: parent.width
              checked: !root.config.menu || root.config.menu.showIcons !== false
              label: "Show icons in power menu"
              onClicked: root.updateMenuConfig("showIcons", !checked)
            }

            Toggle {
              width: parent.width
              checked: !root.config.menu || root.config.menu.showBarIcon !== false
              label: "Show icon on bar"
              onClicked: root.updateMenuConfig("showBarIcon", !checked)
            }

            // Command helper badge shown when bar icon is disabled
            BorderSurface {
              id: cliHintBox
              visible: !root.showBarIcon
              width: parent.width
              implicitHeight: helperCol.implicitHeight + Style.space(20)
              height: implicitHeight
              radius: Style.cornerRadius
              color: Style.normalFillFor(root.fg, Color.accent)
              borderSpec: Border.controlSpec("focus", root.fg, Color.accent)

              Column {
                id: helperCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Row {
                  spacing: Style.space(6)
                  width: parent.width

                  Text {
                    text: "💡"
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "Bar icon hidden. Open Lock Style anytime with:"
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                BorderSurface {
                  width: parent.width
                  implicitHeight: innerCmdRow.implicitHeight + Style.space(16)
                  height: implicitHeight
                  radius: Style.cornerRadius
                  color: Color.background
                  borderSpec: Border.controlSpec("normal", root.fg, Color.accent)

                  Row {
                    id: innerCmdRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(8)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "omarchy-shell shell toggle omarchy-lock-style"
                      color: Color.accent
                      font.family: "JetBrainsMono Nerd Font, monospace"
                      font.pixelSize: Style.space(11.5)
                      font.bold: true
                    }

                    Item {
                      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
                      height: 1
                    }

                    Button {
                      text: copyFeedbackTimer.running ? "✓ Copied!" : "Copy"
                      bordered: true
                      active: copyFeedbackTimer.running
                      anchors.verticalCenter: parent.verticalCenter
                      onClicked: {
                        copyCmdProc.running = false
                        copyCmdProc.running = true
                        copyFeedbackTimer.restart()
                      }
                    }
                  }
                }
              }
            }

            PanelSeparator { foreground: root.fg }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                text: "Bar Icon"
                color: root.fg
                font.family: root.fontFamily
                font.bold: true
              }

              Text {
                text: "Paste custom text/icon"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                TextField {
                  id: barIconField
                  width: Style.space(180)
                  text: root.currentBarIcon
                  placeholderText: "󰌾"
                  onTextEdited: root.updateMenuConfig("barIcon", text)
                }

                // Live Preview Badge of Bar Icon
                BorderSurface {
                  width: Style.space(38)
                  height: Style.space(30)
                  radius: Style.cornerRadius
                  color: Color.background
                  borderSpec: Border.controlSpec("normal", root.fg, Color.accent)

                  Text {
                    anchors.centerIn: parent
                    text: root.currentBarIcon || "󰌾"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(16)
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Quick Presets:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Row {
                spacing: Style.space(6)

                Repeater {
                  model: [
                    { icon: "󰌾", label: "Lock" },
                    { icon: "🔒", label: "Emoji Lock" },
                    { icon: "󰐥", label: "Power" },
                    { icon: "󰣇", label: "Arch Linux" },
                    { icon: "󰮯", label: "User" },
                    { icon: "󰈷", label: "Scan" },
                    { icon: "󰏘", label: "Palette" },
                    { icon: "⚡", label: "Lightning" },
                    { icon: "🐧", label: "Tux Linux" }
                  ]

                  BorderSurface {
                    width: Style.space(32)
                    height: Style.space(32)
                    radius: Style.cornerRadius
                    readonly property bool isSelected: root.currentBarIcon === modelData.icon
                    color: isSelected ? Style.focusFillFor(root.fg, Color.accent) : (mousePreset.containsMouse ? Style.hoverFillFor(root.fg, Color.accent) : Style.normalFillFor(root.fg, Color.accent))
                    borderSpec: Border.controlSpec(isSelected ? "focus" : (mousePreset.containsMouse ? "hover-cursor" : "normal"), root.fg, Color.accent)

                    Text {
                      anchors.centerIn: parent
                      text: modelData.icon
                      color: isSelected ? Color.accent : (mousePreset.containsMouse ? Color.accent : root.fg)
                      font.family: root.fontFamily
                      font.pixelSize: Style.space(16)
                    }

                    MouseArea {
                      id: mousePreset
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.updateMenuConfig("barIcon", modelData.icon)
                        barIconField.text = modelData.icon
                      }
                    }

                    PanelToolTip {
                      visible: mousePreset.containsMouse
                      text: modelData.label
                      fontFamily: root.fontFamily
                    }
                  }
                }
              }
            }
          }

          // TAB 2: POSITION & SCREEN ALIGNMENT
          Column {
            id: positionTab
            visible: root.currentTab === "position"
            width: parent.width
            spacing: Style.space(10)

            Text {
              text: "Alignment Screen"
              color: root.fg
              font.family: root.fontFamily
              font.bold: true
            }

            // Unified 3x3 Mosaic Screen Grid
            BorderSurface {
              width: parent.width
              implicitHeight: positionMosaicGrid.implicitHeight + Style.space(16)
              height: implicitHeight
              radius: Style.cornerRadius
              color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.55)
              borderSpec: Border.controlSpec("normal", root.fg, Color.accent)

              Grid {
                id: positionMosaicGrid
                anchors.centerIn: parent
                width: parent.width - Style.space(16)
                columns: 3
                spacing: Style.space(6)

                readonly property real cellWidth: Math.floor((width - (spacing * 2)) / 3)

                // Row 1
                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Top Left"
                  bordered: true
                  active: root.config.layout && root.config.layout.position === "top_left"
                  onClicked: root.updateConfig("layout", "position", "top_left")
                }

                Item {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                }

                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Top Right"
                  bordered: true
                  active: root.config.layout && root.config.layout.position === "top_right"
                  onClicked: root.updateConfig("layout", "position", "top_right")
                }

                // Row 2
                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Center Left"
                  bordered: true
                  active: root.config.layout && root.config.layout.position === "center_left"
                  onClicked: root.updateConfig("layout", "position", "center_left")
                }

                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Center"
                  bordered: true
                  active: !root.config.layout || root.config.layout.position === "center" || !root.config.layout.position
                  onClicked: root.updateConfig("layout", "position", "center")
                }

                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Center Right"
                  bordered: true
                  active: root.config.layout && root.config.layout.position === "center_right"
                  onClicked: root.updateConfig("layout", "position", "center_right")
                }

                // Row 3
                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Bottom Left"
                  bordered: true
                  active: root.config.layout && root.config.layout.position === "bottom_left"
                  onClicked: root.updateConfig("layout", "position", "bottom_left")
                }

                Item {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                }

                Button {
                  width: positionMosaicGrid.cellWidth
                  height: Style.space(36)
                  text: "Bottom Right"
                  bordered: true
                  active: root.config.layout && root.config.layout.position === "bottom_right"
                  onClicked: root.updateConfig("layout", "position", "bottom_right")
                }
              }
            }
          }

          // TAB 3: CLOCK & DATE
          Column {
            id: clockTab
            visible: root.currentTab === "clock"
            width: parent.width
            spacing: Style.space(10)

            readonly property real switchColWidth: Math.floor((width - Style.space(16)) / 2)

            // Row 1: Switches 1 & 2
            Row {
              width: parent.width
              spacing: Style.space(16)

              Toggle {
                width: clockTab.switchColWidth
                checked: !root.config.clock || root.config.clock.enabled !== false
                label: "Enable Clock on Lock Screen"
                onClicked: root.updateConfig("clock", "enabled", !checked)
              }

              Toggle {
                width: clockTab.switchColWidth
                checked: !root.config.date || root.config.date.enabled !== false
                label: "Show Date on Lock Screen"
                onClicked: root.updateConfig("date", "enabled", !checked)
              }
            }

            // Row 2: Switches 3 & 4
            Row {
              width: parent.width
              spacing: Style.space(16)

              Toggle {
                width: clockTab.switchColWidth
                checked: root.config.clock ? root.config.clock.format === "12h" : false
                label: "Use 12-Hour Format (AM/PM)"
                onClicked: root.updateConfig("clock", "format", checked ? "24h" : "12h")
              }

              Toggle {
                width: clockTab.switchColWidth
                checked: root.config.clock ? root.config.clock.layout === "vertical" : false
                label: "Vertical Clock Layout (Stacked)"
                onClicked: root.updateConfig("clock", "layout", checked ? "horizontal" : "vertical")
              }
            }

            PanelSeparator { foreground: root.fg }

            // Position Controls for Clock and Date
            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                spacing: Style.space(4)
                Text { text: "Clock Position:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Row {
                  spacing: Style.space(6)
                  Button {
                    text: "Above PIN Box"
                    active: !root.config.clock || root.config.clock.position !== "below_pin"
                    bordered: true
                    onClicked: root.updateConfig("clock", "position", "above_pin")
                  }
                  Button {
                    text: "Below PIN Box"
                    active: root.config.clock && root.config.clock.position === "below_pin"
                    bordered: true
                    onClicked: root.updateConfig("clock", "position", "below_pin")
                  }
                }
              }

              Column {
                spacing: Style.space(4)
                Text { text: "Date Position:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Row {
                  spacing: Style.space(6)
                  Button {
                    text: "Above Clock"
                    active: root.config.date && root.config.date.position === "above_clock"
                    bordered: true
                    onClicked: root.updateConfig("date", "position", "above_clock")
                  }
                  Button {
                    text: "Below Clock"
                    active: !root.config.date || root.config.date.position !== "above_clock"
                    bordered: true
                    onClicked: root.updateConfig("date", "position", "below_clock")
                  }
                }
              }
            }

            // Font & Date Format Controls
            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                spacing: Style.space(4)
                Text { text: "Font Family (" + root.systemFonts.length + " fonts):"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }

                Item {
                  id: fontDropdown
                  width: Style.space(260)
                  height: Style.space(32)

                  property string value: (root.config.clock && root.config.clock.fontFamily) ? root.config.clock.fontFamily : "JetBrainsMono Nerd Font"
                  property var options: root.systemFonts
                  property bool open: false

                  BorderSurface {
                    id: fontTrigger
                    anchors.fill: parent
                    radius: Style.cornerRadius
                    color: fontMouse.containsMouse || fontDropdown.open ? Style.hoverFillFor(root.fg, Color.accent) : Color.background
                    borderSpec: Border.controlSpec(fontDropdown.open ? "focus" : (fontMouse.containsMouse ? "hover-cursor" : "normal"), root.fg, Color.accent)

                    Row {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(10)
                      anchors.rightMargin: Style.space(10)
                      spacing: Style.space(6)

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(24)
                        text: fontDropdown.value
                        color: root.fg
                        font.family: fontDropdown.value
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: fontDropdown.open ? "󰅃" : "󰅀"
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    MouseArea {
                      id: fontMouse
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      hoverEnabled: true
                      onClicked: fontDropdown.open = !fontDropdown.open
                    }
                  }

                  // Upward Popup List
                  Popup {
                    id: fontPopup
                    visible: fontDropdown.open
                    onClosed: fontDropdown.open = false
                    x: 0
                    y: -height - Style.space(4)
                    width: parent.width
                    height: Math.min(Style.space(220), (fontDropdown.options.length * Style.space(28)) + Style.space(12))
                    padding: Style.space(4)
                    focus: true

                    background: BorderSurface {
                      color: Color.popups.background || Color.background
                      borderSpec: Border.controlSpec("focus", root.fg, Color.accent)
                      radius: Style.cornerRadius
                    }

                    contentItem: ListView {
                      id: fontListView
                      clip: true
                      model: fontDropdown.options
                      currentIndex: fontDropdown.options.indexOf(fontDropdown.value)

                      Component.onCompleted: {
                        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Center)
                      }

                      delegate: BorderSurface {
                        width: fontListView.width
                        height: Style.space(26)
                        radius: Style.cornerRadius
                        color: fontItemMouse.containsMouse || fontDropdown.value === modelData
                          ? Style.hoverFillFor(root.fg, Color.accent)
                          : "transparent"
                        borderSpec: Border.controlSpec(fontDropdown.value === modelData ? "focus" : "normal", root.fg, Color.accent)

                        Text {
                          anchors.left: parent.left
                          anchors.leftMargin: Style.space(8)
                          anchors.right: parent.right
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          text: modelData
                          color: fontDropdown.value === modelData ? Color.accent : root.fg
                          font.family: modelData
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }

                        MouseArea {
                          id: fontItemMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            fontDropdown.value = modelData
                            root.updateConfig("clock", "fontFamily", modelData)
                            fontDropdown.open = false
                          }
                        }
                      }
                    }
                  }
                }
              }

              Column {
                spacing: Style.space(4)
                Text { text: "Date Format:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Row {
                  spacing: Style.space(6)
                  Button {
                    text: "Full Date"
                    active: !root.config.date || !root.config.date.format || root.config.date.format === "dddd, MMMM d"
                    bordered: true
                    onClicked: root.updateConfig("date", "format", "dddd, MMMM d")
                  }
                  Button {
                    text: "Compact"
                    active: root.config.date && root.config.date.format === "ddd, d MMM"
                    bordered: true
                    onClicked: root.updateConfig("date", "format", "ddd, d MMM")
                  }
                  Button {
                    text: "ISO (YYYY-MM-DD)"
                    active: root.config.date && root.config.date.format === "yyyy-MM-dd"
                    bordered: true
                    onClicked: root.updateConfig("date", "format", "yyyy-MM-dd")
                  }
                }
              }
            }
          }

          // TAB 4: PIN BOX
          Column {
            id: pinTab
            visible: root.currentTab === "pin"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "PIN Box Display Mode:"; color: root.fg; font.family: root.fontFamily; font.bold: true }

            Row {
              spacing: Style.space(6)
              Button {
                text: "Dots (●)"
                active: !root.config.pinBox || root.config.pinBox.mode === "dots"
                bordered: true
                onClicked: root.updateConfig("pinBox", "mode", "dots")
              }
              Button {
                text: "Asterisks (*)"
                active: root.config.pinBox && root.config.pinBox.mode === "asterisks"
                bordered: true
                onClicked: root.updateConfig("pinBox", "mode", "asterisks")
              }
              Button {
                text: "Dashes (—)"
                active: root.config.pinBox && root.config.pinBox.mode === "dashes"
                bordered: true
                onClicked: root.updateConfig("pinBox", "mode", "dashes")
              }
              Button {
                text: "Stealth (Blank)"
                active: root.config.pinBox && root.config.pinBox.mode === "stealth"
                bordered: true
                onClicked: root.updateConfig("pinBox", "mode", "stealth")
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Row {
                width: parent.width

                Text {
                  text: "PIN Box Width (" + Math.round(boxWidthSlider.liveValue) + "px):"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Item {
                  width: Math.max(0, parent.width - Style.space(240))
                  height: 1
                }

                Text {
                  text: "Default / Max: 380px"
                  color: root.subdim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              PanelSlider {
                id: boxWidthSlider
                width: parent.width
                bar: root.bar
                minimum: 180
                maximum: 380
                step: 5
                integer: true
                value: (root.config.pinBox && root.config.pinBox.width) ? Math.min(380, root.config.pinBox.width) : 380
                fillColor: Color.accent
                knobColor: Color.accent
                trackColor: Style.hoverFillFor(root.fg, Color.accent)
                onMoved: function(val) {
                  var w = Math.round(val)
                  root.updateConfig("pinBox", "width", w)
                  var h = Math.round(50 + ((w - 180) / (380 - 180)) * 16)
                  var fs = Math.round(16 + ((w - 180) / (380 - 180)) * 6)
                  root.updateConfig("pinBox", "height", h)
                  root.updateConfig("pinBox", "fontSize", fs)
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                spacing: Style.space(4)
                Text { text: "Corner Radius (" + (root.config.pinBox ? root.config.pinBox.radius : 18) + "px):"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                Row {
                  spacing: Style.space(6)
                  Button {
                    text: "Square (4px)"
                    active: root.config.pinBox && root.config.pinBox.radius <= 4
                    bordered: true
                    onClicked: root.updateConfig("pinBox", "radius", 4)
                  }
                  Button {
                    text: "Rounded (14px)"
                    active: root.config.pinBox && root.config.pinBox.radius === 14
                    bordered: true
                    onClicked: root.updateConfig("pinBox", "radius", 14)
                  }
                  Button {
                    text: "Medium (20px)"
                    active: root.config.pinBox && root.config.pinBox.radius === 20
                    bordered: true
                    onClicked: root.updateConfig("pinBox", "radius", 20)
                  }
                  Button {
                    text: "Pill (32px)"
                    active: root.config.pinBox && root.config.pinBox.radius >= 30
                    bordered: true
                    onClicked: root.updateConfig("pinBox", "radius", 32)
                  }
                }
              }
            }
          }

          // TAB 4: USER & QUOTES
          Column {
            id: userTab
            visible: root.currentTab === "user"
            width: parent.width
            spacing: Style.space(10)

            Toggle {
              width: parent.width
              checked: !root.config.user || root.config.user.avatarEnabled !== false
              label: "Show Avatar Circle"
              onClicked: root.updateConfig("user", "avatarEnabled", !checked)
            }

            Toggle {
              width: parent.width
              checked: !root.config.user || root.config.user.greetingEnabled !== false
              label: "Enable Welcome for User"
              onClicked: root.updateConfig("user", "greetingEnabled", !checked)
            }

            PanelSeparator { foreground: root.fg }

            Toggle {
              width: parent.width
              checked: root.config.user ? root.config.user.quoteEnabled === true : true
              label: "Enable Quotes on Lock (Random Developer Quotes)"
              onClicked: root.updateConfig("user", "quoteEnabled", !checked)
            }

            // Custom text input when quotes are disabled
            Column {
              visible: root.config.user && root.config.user.quoteEnabled === false
              width: parent.width
              spacing: Style.space(4)

              Text {
                text: "Custom Message (Optional):"
                color: root.fg
                font.family: root.fontFamily
                font.bold: true
              }

              Text {
                text: "Enter custom text to display below greeting (leave empty to show nothing)"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              TextField {
                id: customUserTextField
                width: parent.width
                text: (root.config.user && root.config.user.customText) ? root.config.user.customText : ""
                placeholderText: "e.g. Have a productive day!"
                onTextEdited: root.updateConfig("user", "customText", text)
              }
            }
          }

          // TAB 5: MEDIA
          Column {
            id: mediaTab
            visible: root.currentTab === "media"
            width: parent.width
            spacing: Style.space(10)

            Toggle {
              width: parent.width
              checked: root.config.media ? root.config.media.enabled : true
              label: "Display playing music info at screen bottom"
              onClicked: root.updateConfig("media", "enabled", !checked)
            }

            Text {
              text: "When music is playing via Spotify, Firefox, MPV or any MPRIS player, an elegant music card will automatically appear at the bottom of the lock screen."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              width: parent.width
            }
          }

          // TAB 6: VISUALS
          Column {
            id: visualsTab
            visible: root.currentTab === "visuals"
            width: parent.width
            spacing: Style.space(10)

            Toggle {
              width: parent.width
              checked: root.config.visuals ? root.config.visuals.animations : true
              label: "Enable Smooth Animations"
              onClicked: root.updateConfig("visuals", "animations", !checked)
            }

            Toggle {
              width: parent.width
              checked: root.config.visuals ? root.config.visuals.pulseColon : true
              label: "Pulse Clock Colon (:)"
              onClicked: root.updateConfig("visuals", "pulseColon", !checked)
            }

            Toggle {
              width: parent.width
              checked: root.config.visuals ? root.config.visuals.breathingFocus : true
              label: "Breathing Focus Effect on PIN Box"
              onClicked: root.updateConfig("visuals", "breathingFocus", !checked)
            }
          }

          // TAB 7: WALLPAPER & BLUR
          Column {
            id: wallpaperTab
            visible: root.currentTab === "wallpaper"
            width: parent.width
            spacing: Style.space(10)

            // Current wallpaper status & source actions
            Row {
              width: parent.width
              spacing: Style.space(10)

              Button {
                text: "Browse Wallpaper..."
                bordered: true
                onClicked: {
                  root.isBrowsing = true
                  pickWallpaperProc.running = false
                  pickWallpaperProc.running = true
                }
              }

              Button {
                text: "Restore System Wallpaper"
                bordered: true
                active: !root.config.wallpaper || root.config.wallpaper.mode === "system" || !root.config.wallpaper.customPath
                onClicked: root.restoreSystemWallpaper()
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.config.wallpaper && root.config.wallpaper.mode === "custom" && root.config.wallpaper.customPath) ? "Using Custom Lock Wallpaper" : "Using System Wallpaper"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // Saved / Recent Wallpapers Gallery
            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: root.config.wallpaper && root.config.wallpaper.history && root.config.wallpaper.history.length > 0

              Text {
                text: "Recent Wallpapers:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Row {
                spacing: Style.space(8)

                Repeater {
                  model: (root.config.wallpaper && root.config.wallpaper.history) ? root.config.wallpaper.history : []

                  BorderSurface {
                    width: Style.space(64)
                    height: Style.space(38)
                    radius: Style.cornerRadius
                    readonly property bool isSelected: root.config.wallpaper && root.config.wallpaper.customPath === modelData.path && root.config.wallpaper.mode === "custom"
                    color: Color.background
                    borderSpec: Border.controlSpec(isSelected ? "focus" : (mouseWp.containsMouse ? "hover-cursor" : "normal"), root.fg, Color.accent)
                    clip: true

                    Image {
                      anchors.fill: parent
                      source: "file://" + modelData.path
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                    }

                    MouseArea {
                      id: mouseWp
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.applySelectedCustomWallpaper(modelData.path, modelData.path)
                    }

                    // Individual Delete Button on thumbnail
                    Rectangle {
                      visible: mouseWp.containsMouse || deleteMouse.containsMouse
                      anchors.top: parent.top
                      anchors.right: parent.right
                      anchors.margins: Style.space(2)
                      width: Style.space(16)
                      height: Style.space(16)
                      radius: width / 2
                      color: deleteMouse.containsMouse ? Color.urgent : Qt.rgba(0, 0, 0, 0.75)
                      z: 10

                      Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#FFFFFF"
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(8.5)
                        font.bold: true
                      }

                      MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                          mouse.accepted = true;
                          root.deleteSavedWallpaper(modelData.path);
                        }
                      }
                    }

                    PanelToolTip {
                      visible: mouseWp.containsMouse && !deleteMouse.containsMouse
                      text: modelData.name || "Custom Wallpaper"
                      fontFamily: root.fontFamily
                    }
                  }
                }
              }
            }

            PanelSeparator { foreground: root.fg }

            // Lock Screen Blur Control
            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                spacing: Style.space(4)
                Text {
                  text: "Lock Screen Blur (" + Math.round(((root.config.wallpaper && root.config.wallpaper.blur !== undefined) ? root.config.wallpaper.blur : 1.0) * 100) + "%):"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  spacing: Style.space(6)

                  Button {
                    text: "Off (0%)"
                    active: root.config.wallpaper && root.config.wallpaper.blur === 0.0
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "blur", 0.0)
                  }

                  Button {
                    text: "Light (25%)"
                    active: root.config.wallpaper && root.config.wallpaper.blur === 0.25
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "blur", 0.25)
                  }

                  Button {
                    text: "Standard (50%)"
                    active: !root.config.wallpaper || root.config.wallpaper.blur === 0.5 || (root.config.wallpaper.blur === undefined)
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "blur", 0.5)
                  }

                  Button {
                    text: "Heavy (100%)"
                    active: root.config.wallpaper && root.config.wallpaper.blur === 1.0
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "blur", 1.0)
                  }

                  Button {
                    text: "Max (150%)"
                    active: root.config.wallpaper && root.config.wallpaper.blur === 1.5
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "blur", 1.5)
                  }
                }
              }
            }

            // Lock Screen Darkness Tint
            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                spacing: Style.space(4)
                Text {
                  text: "Darkness Overlay (" + Math.round(((root.config.wallpaper && root.config.wallpaper.dim !== undefined) ? root.config.wallpaper.dim : 0.22) * 100) + "%):"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  spacing: Style.space(6)

                  Button {
                    text: "Clear (0%)"
                    active: root.config.wallpaper && root.config.wallpaper.dim === 0.0
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "dim", 0.0)
                  }

                  Button {
                    text: "Subtle (12%)"
                    active: root.config.wallpaper && root.config.wallpaper.dim === 0.12
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "dim", 0.12)
                  }

                  Button {
                    text: "Standard (22%)"
                    active: !root.config.wallpaper || root.config.wallpaper.dim === 0.22 || (root.config.wallpaper.dim === undefined)
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "dim", 0.22)
                  }

                  Button {
                    text: "Dark (38%)"
                    active: root.config.wallpaper && root.config.wallpaper.dim === 0.38
                    bordered: true
                    onClicked: root.updateConfig("wallpaper", "dim", 0.38)
                  }
                }
              }
            }
          }
        }

        // ==========================================
        // 5. FOOTER
        // ==========================================
        Item {
          width: parent.width
          height: Style.space(30)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusMessage
            color: root.statusIsError ? Color.lock.borderError : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          // Footer buttons for Lock Screen tabs (Clock, PIN, User, Media, Visuals)
          Row {
            visible: root.currentTab !== "menu"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Button {
              text: "Cancel"
              tooltipText: "Discard unapplied changes"
              bordered: true
              onClicked: root.cancelChanges()
            }

            Button {
              text: "Restore Original"
              tooltipText: "Restore factory stock lock screen"
              bordered: true
              onClicked: root.restoreOriginal()
            }

            Button {
              text: "Apply"
              tooltipText: "Save and apply custom style to system lock screen"
              bordered: true
              foreground: Color.accent
              onClicked: root.applyLockStyle()
            }
          }
        }
      }
    }
  }
}
