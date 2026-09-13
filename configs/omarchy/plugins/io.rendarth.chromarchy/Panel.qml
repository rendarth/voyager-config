import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.rendarth.chromarchy"
  manageIpc: false

  // Host widget and identity tracking
  property var hostWidget: null
  property var anchorItem: null
  readonly property var barIdentity: hostWidget || root
  property bool openedFromHotkey: false
  property string statusToast: ""
  property bool editingKeywords: false

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  // Active bar section ("left" | "center" | "right")
  readonly property string currentBarSection: {
    if (root.bar && root.bar.shell && root.bar.shell.config && root.bar.shell.config.bar && root.bar.shell.config.bar.layout) {
      var layout = root.bar.shell.config.bar.layout
      var sections = ["left", "center", "right"]
      for (var s = 0; s < sections.length; s++) {
        var sec = sections[s]
        var arr = layout[sec] || []
        for (var i = 0; i < arr.length; i++) {
          var item = arr[i]
          var id = (typeof item === "string") ? item : (item && item.id)
          if (id === root.moduleName) return sec
        }
      }
    }
    return "right"
  }

  function moveBarSection(targetSection) {
    if (!targetSection || targetSection === root.currentBarSection) return
    barMoveProc.targetSection = targetSection
    barMoveProc.command = ["omarchy", "bar", "move", root.moduleName, "--section", targetSection]
    barMoveProc.running = true
  }

  Process {
    id: barMoveProc
    running: false
    property string targetSection: ""
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        root.showToast("Moved to " + barMoveProc.targetSection + " bar section")
      } else {
        root.showToast("Failed to move bar section")
      }
    }
  }

  // View state management: "MAIN" | "SETTINGS"
  property string activeView: "MAIN"

  // Settings from inline shell.json
  readonly property string colorMode: setting("colorMode", "matching")
  readonly property var colorKeys: {
    var k = setting("colorKeys", ["accent", "background"])
    return Array.isArray(k) && k.length > 0 ? k : ["accent", "background"]
  }
  readonly property string keywords: setting("keywords", "")
  readonly property string category: setting("category", "general")
  readonly property string purity: setting("purity", "sfw")
  readonly property string fetchMode: setting("fetchMode", "prefetch")
  readonly property int prefetchCount: Math.max(1, Math.min(20, parseInt(setting("prefetchCount", 10), 10) || 10))
  readonly property int interval: parseInt(setting("interval", 1800), 10) || 1800
  readonly property string multiMonitor: setting("multiMonitor", "same")
  readonly property string saveBehavior: setting("saveBehavior", "rotate")
  readonly property bool allowDuplicates: setting("allowDuplicates", false) === true
  readonly property int maxScore: {
    var v = parseInt(setting("maxScore", 0), 10)
    return (v > 0) ? v : 0  // 0 means no limit
  }

  // Persist settings changes back to shell.json inline entry
  function persistSettings(values, shouldFetch) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) {
      if (existing !== "id") entry[existing] = root.settings[existing]
    }
    for (var key in values) {
      entry[key] = values[key]
    }

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) {
      root.hostWidget.settings = entry
    }
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }

    // Automatically trigger a fetch when search or color preferences change
    if (shouldFetch === true || "colorMode" in values || "colorKeys" in values || "category" in values || "purity" in values || "keywords" in values || "maxScore" in values) {
      Qt.callLater(function() {
        cacheManager.fetchBatch()
      })
    }
  }

  // Panel lifecycle functions
  function open() {
    root.activeView = "MAIN"
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  function openFromHotkey() {
    root.activeView = "MAIN"
    openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    root.activeView = "MAIN"
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // Toast feedback helper
  function showToast(msg) {
    root.statusToast = msg
    toastTimer.restart()
  }

  Timer {
    id: toastTimer
    interval: 3000
    repeat: false
    onTriggered: root.statusToast = ""
  }

  // Fallback active background path
  readonly property string defaultBackgroundPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"

  // Core Service / Cache Backend
  CacheManager {
    id: cacheManager
    colorMode: root.colorMode
    colorKeys: root.colorKeys
    keywords: root.keywords
    category: root.category
    purity: root.purity
    fetchMode: root.fetchMode
    prefetchCount: root.prefetchCount
    interval: root.interval
    multiMonitor: root.multiMonitor
    saveBehavior: root.saveBehavior
    allowDuplicates: root.allowDuplicates
    maxScore: root.maxScore

    onWallpaperSaved: function(targetPath, mode) {
      root.showToast("Saved to " + (mode === "rotate" ? "backgrounds/" : "saved-wallpapers/"))
    }
    onErrorOccurred: function(msg) {
      root.showToast("Error: " + msg)
    }
  }

  // Reactive state bindings from CacheManager
  readonly property var currentWp: cacheManager.currentWallpaper
  readonly property string currentWallpaperPath: (currentWp && currentWp.localFile) ? currentWp.localFile : root.defaultBackgroundPath
  readonly property string currentWallpaperId: (currentWp && currentWp.id) ? currentWp.id : ""
  readonly property string currentWallpaperUrl: {
    var raw = (currentWp && currentWp.url) ? currentWp.url : (currentWallpaperId ? ("https://wallhaven.cc/w/" + currentWallpaperId) : "")
    return /^https:\/\/wallhaven\.cc\/w\/[a-zA-Z0-9]+$/.test(raw) ? raw : ""
  }
  readonly property real currentScore: (currentWp && currentWp.score !== undefined) ? currentWp.score : -1
  readonly property var currentColors: (currentWp && currentWp.colors) ? currentWp.colors : []
  readonly property bool isPaused: cacheManager.isPaused
  readonly property bool isFetching: cacheManager.isFetching || cacheManager.isDownloading
  readonly property string statusMessage: cacheManager.statusText
  readonly property int cachedCount: cacheManager.currentBatch ? cacheManager.currentBatch.length : 0
  readonly property int historyCount: cacheManager.history ? cacheManager.history.length : 0
  readonly property string activeThemeName: cacheManager.activeThemeName || "eventide"
  readonly property string displayThemeName: activeThemeName ? (activeThemeName.charAt(0).toUpperCase() + activeThemeName.slice(1)) : "Theme"

  // Quick Action methods
  function nextWallpaper() {
    cacheManager.nextWallpaper()
    root.showToast("Rotating wallpaper...")
  }

  function saveCurrent() {
    cacheManager.saveCurrentWallpaper(root.saveBehavior)
  }

  function saveCurrentWallpaper(behavior) {
    cacheManager.saveCurrentWallpaper(behavior || root.saveBehavior)
  }

  function togglePause() {
    cacheManager.togglePause()
    root.showToast(cacheManager.isPaused ? "Rotation paused" : "Rotation resumed")
  }

  function clearCache() {
    cacheManager.clearHistory()
    root.showToast("Cache and history reset")
  }

  // Theme Color Selection Helpers
  function toggleColorKey(key) {
    var list = (root.colorKeys || []).slice(0)
    var idx = list.indexOf(key)
    if (idx >= 0) {
      if (list.length > 1) {
        list.splice(idx, 1)
        persistSettings({ colorKeys: list })
      } else {
        root.showToast("At least one theme color must remain selected")
      }
    } else {
      list.push(key)
      persistSettings({ colorKeys: list })
    }
  }

  function setPrimaryColorKey(key) {
    var list = (root.colorKeys || []).slice(0)
    var idx = list.indexOf(key)
    if (idx >= 0) {
      list.splice(idx, 1)
    }
    list.unshift(key)
    persistSettings({ colorKeys: list })
    root.showToast("Set " + key + " as primary API search color")
  }

  readonly property var paletteKeys: [
    "accent", "background", "foreground", "muted", "urgent",
    "red", "orange", "yellow", "green", "cyan", "blue", "magenta"
  ]

  function getHexForThemeKey(key) {
    if (cacheManager.colorUtils && typeof cacheManager.colorUtils.getColor === "function") {
      var h = cacheManager.colorUtils.getColor(key)
      if (h && h.length > 0) return cacheManager.colorUtils.ensureHash(h)
    }
    if (cacheManager.colorUtils && typeof cacheManager.colorUtils.getThemeColor === "function") {
      var h2 = cacheManager.colorUtils.getThemeColor(key)
      if (h2 && h2.length > 0) return cacheManager.colorUtils.ensureHash(h2)
    }
    if (key === "accent") return String(Color.accent)
    if (key === "background") return String(Color.background)
    if (key === "foreground") return String(Color.foreground)
    if (key === "urgent") return String(Color.urgent)
    if (key === "muted") return String(Color.muted)
    if (key === "red") return "#cc3333"
    if (key === "orange") return "#ff6600"
    if (key === "yellow") return "#ffff00"
    if (key === "green") return "#669900"
    if (key === "cyan") return "#0099cc"
    if (key === "blue") return "#0066cc"
    if (key === "magenta") return "#993399"
    return "#888888"
  }

  // The Popup Window (Layer-Shell)
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(
      headerRow.implicitHeight
      + (root.statusToast !== "" ? toastBox.implicitHeight + Style.space(12) : 0)
      + (root.activeView === "MAIN" ? mainColumn.implicitHeight : settingsColumn.implicitHeight)
      + Style.space(36),
      Style.space(640)
    )

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      blocked: root.editingKeywords
      onCloseRequested: {
        if (root.activeView === "SETTINGS") root.activeView = "MAIN"
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx > 0) root.nextWallpaper()
        else if (dx < 0) cacheManager.prevWallpaper()
      }
      onTextKey: function(t) {
        var key = t.toLowerCase()
        if (key === "n") root.nextWallpaper()
        else if (key === "s") root.saveCurrent()
        else if (key === "p") root.togglePause()
        else if (key === "r") cacheManager.fetchBatch()
        else if (key === "o") {
          if (root.currentWallpaperUrl) Qt.openUrlExternally(root.currentWallpaperUrl)
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(12)

        // 1. Header Row
        RowLayout {
          id: headerRow
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: root.activeView === "SETTINGS" ? "󰒓" : "󰬸"
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            color: Color.accent
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              text: root.activeView === "SETTINGS" ? "Settings" : "Chromarchy"
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              color: Color.popups.text
            }

            Text {
              text: root.activeView === "SETTINGS"
                ? "Preferences & Configuration"
                : (root.isPaused ? "Rotation Paused (P)" : ("Auto-rotation Active • " + Math.round(root.interval / 60) + "m"))
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(Color.popups.text, 1.4)
            }
          }

          PanelActionButton {
            iconText: root.activeView === "SETTINGS" ? "󰁍" : "󰒓"
            tooltipText: root.activeView === "SETTINGS" ? "Back to Main (Esc)" : "Settings"
            foreground: Color.popups.text
            hoverColor: Color.accent
            onClicked: {
              root.activeView = (root.activeView === "SETTINGS" ? "MAIN" : "SETTINGS")
            }
          }
        }

        // Toast feedback notice
        BorderSurface {
          id: toastBox
          visible: root.statusToast !== ""
          Layout.fillWidth: true
          radius: Style.cornerRadius
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
          borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)
          padding: Style.space(6)

          Text {
            anchors.centerIn: parent
            text: root.statusToast
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Color.accent
          }
        }

        // Scrollable content area
        Flickable {
          id: flickable
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: root.activeView === "MAIN" ? mainColumn.implicitHeight : settingsColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height

          ScrollBar.vertical: ScrollBar {
            policy: flickable.contentHeight > flickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
          }

          Connections {
            target: root
            function onActiveViewChanged() {
              flickable.contentY = 0
            }
          }

          // ==========================================
          // MAIN VIEW COLUMN
          // ==========================================
          Column {
            id: mainColumn
            visible: root.activeView === "MAIN"
            width: flickable.width - (flickable.contentHeight > flickable.height ? Style.space(12) : 0)
            spacing: Style.space(10)

            // Active Theme & Target Swatches Row
            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              BorderSurface {
                radius: Style.space(6)
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
                borderSpec: Border.flat(Color.accent, 1)
                implicitHeight: Style.space(26)
                implicitWidth: themeRow.implicitWidth + Style.space(20)

                Row {
                  id: themeRow
                  anchors.centerIn: parent
                  spacing: Style.space(6)
                  Text {
                    text: "󰏘"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.accent
                  }
                  Text {
                    text: root.displayThemeName
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.popups.text
                  }
                }
              }

              Text {
                text: "Theme Colors:"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.darker(Color.popups.text, 1.4)
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: root.colorKeys
                  Rectangle {
                    width: Style.space(18)
                    height: Style.space(18)
                    radius: Style.space(9)
                    color: root.getHexForThemeKey(modelData)
                    border.width: index === 0 ? 2 : 1
                    border.color: index === 0 ? Color.accent : Qt.rgba(1, 1, 1, 0.5)

                    Text {
                      anchors.centerIn: parent
                      text: String(index + 1)
                      font.family: Style.font.family
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: (Qt.colorEqual(parent.color, "#000000") || parent.color.hslLightness < 0.5) ? "#ffffff" : "#000000"
                    }
                  }
                }
              }

              Item { Layout.fillWidth: true }
            }

            // Wallpaper Preview Card
            BorderSurface {
              id: previewCard
              width: parent.width
              implicitHeight: Style.space(160)
              radius: Style.cornerRadius
              color: Qt.darker(Color.popups.background, 1.15)
              borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
              clip: true

              Image {
                id: previewImg
                anchors.fill: parent
                source: Util.fileUrl(root.currentWallpaperPath)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true

                Text {
                  visible: previewImg.status !== Image.Ready
                  anchors.centerIn: parent
                  text: root.isFetching ? "󰦖 Fetching wallpaper..." : "Active Omarchy Background"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  color: Qt.darker(Color.popups.text, 1.5)
                }
              }

              // Bottom gradient overlay for legible text
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Style.space(46)
                gradient: Gradient {
                  GradientStop { position: 0.0; color: "transparent" }
                  GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                }
              }

              // Top badges (ID & Match Score)
              RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(8)

                BorderSurface {
                  implicitHeight: Style.space(22)
                  implicitWidth: idRow.implicitWidth + Style.space(16)
                  radius: Style.space(4)
                  color: Qt.rgba(0, 0, 0, 0.72)
                  borderSpec: Border.flat(Color.accent, 1)

                  Row {
                    id: idRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)

                    Text {
                      text: root.currentWallpaperId ? ("󰌹 " + root.currentWallpaperId) : "󰸉 Desktop Background"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: "#ffffff"
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: root.currentWallpaperUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.currentWallpaperUrl !== ""
                    onClicked: {
                      if (root.currentWallpaperUrl) Qt.openUrlExternally(root.currentWallpaperUrl)
                    }
                  }
                }

                Item { Layout.fillWidth: true }

                BorderSurface {
                  id: scoreBadge
                  visible: root.currentScore >= 0
                  implicitHeight: Style.space(22)
                  implicitWidth: scoreText.implicitWidth + Style.space(16)
                  radius: Style.space(4)
                  color: Qt.rgba(0, 0, 0, 0.72)
                  borderSpec: Border.flat(Color.accent, 1)

                  Text {
                    id: scoreText
                    anchors.centerIn: parent
                    text: "Score: " + Math.round(root.currentScore)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: "#ffffff"
                  }

                  MouseArea {
                    id: scoreMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  PanelToolTip {
                    visible: scoreMouse.containsMouse
                    text: {
                      var s = Math.round(root.currentScore)
                      var quality = s <= 20 ? "Excellent Match" : (s <= 35 ? "Good Match" : "Moderate Match")
                      return "Harmony Score: " + s + " (" + quality + ")\n" +
                             "• Lower score = closer match to your active theme\n" +
                             "• < 20: High fidelity theme match\n" +
                             "• 20–35: Strong palette harmony\n" +
                             "• > 35: Loose or accent match"
                    }
                  }
                }
              }

              // Bottom info (Palette dots + status)
              RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)

                Row {
                  spacing: Style.space(4)
                  visible: root.currentColors && root.currentColors.length > 0

                  Repeater {
                    model: root.currentColors
                    Rectangle {
                      width: Style.space(12)
                      height: Style.space(12)
                      radius: Style.space(6)
                      color: String(modelData).indexOf("#") === 0 ? modelData : ("#" + modelData)
                      border.width: 1
                      border.color: Qt.rgba(1, 1, 1, 0.3)
                    }
                  }
                }

                Item { Layout.fillWidth: true }

                Text {
                  Layout.maximumWidth: Style.space(240)
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                  text: root.statusMessage
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: "#ffffff"
                }
              }
            }

            // Quick Actions Row
            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - Style.space(16)) / 3
                implicitHeight: Style.space(44)
                iconText: "󰒭"
                text: "Next"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Rotate to next wallpaper (Shortcut: N, Middle-click)"
                onClicked: root.nextWallpaper()

                BorderSurface {
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(3)
                  anchors.horizontalCenter: parent.horizontalCenter
                  implicitHeight: Style.space(13)
                  implicitWidth: Style.space(16)
                  radius: Style.space(2)
                  color: Qt.rgba(0, 0, 0, 0.4)
                  borderSpec: Border.flat(Qt.darker(Color.popups.text, 2.0), 1)

                  Text {
                    anchors.centerIn: parent
                    text: "N"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption - 3
                    font.bold: true
                    color: Qt.darker(Color.popups.text, 1.4)
                  }
                }
              }

              Button {
                width: (parent.width - Style.space(16)) / 3
                implicitHeight: Style.space(44)
                iconText: "󰋑"
                text: "Save"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Save wallpaper to " + (root.saveBehavior === "rotate" ? "backgrounds/" : "saved-wallpapers/") + " (Shortcut: S, Right-click)"
                onClicked: root.saveCurrent()

                BorderSurface {
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(3)
                  anchors.horizontalCenter: parent.horizontalCenter
                  implicitHeight: Style.space(13)
                  implicitWidth: Style.space(16)
                  radius: Style.space(2)
                  color: Qt.rgba(0, 0, 0, 0.4)
                  borderSpec: Border.flat(Qt.darker(Color.popups.text, 2.0), 1)

                  Text {
                    anchors.centerIn: parent
                    text: "S"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption - 3
                    font.bold: true
                    color: Qt.darker(Color.popups.text, 1.4)
                  }
                }
              }

              Button {
                width: (parent.width - Style.space(16)) / 3
                implicitHeight: Style.space(44)
                iconText: root.isPaused ? "󰐊" : "󰏤"
                text: root.isPaused ? "Resume" : "Pause"
                bordered: true
                selected: root.isPaused
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: root.isPaused ? "Resume automatic rotation (Shortcut: P)" : "Pause rotation timer (Shortcut: P)"
                onClicked: root.togglePause()

                BorderSurface {
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(3)
                  anchors.horizontalCenter: parent.horizontalCenter
                  implicitHeight: Style.space(13)
                  implicitWidth: Style.space(16)
                  radius: Style.space(2)
                  color: Qt.rgba(0, 0, 0, 0.4)
                  borderSpec: Border.flat(Qt.darker(Color.popups.text, 2.0), 1)

                  Text {
                    anchors.centerIn: parent
                    text: "P"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption - 3
                    font.bold: true
                    color: Qt.darker(Color.popups.text, 1.4)
                  }
                }
              }
            }

            // Active Search Keywords Chip (Click to Clear)
            BorderSurface {
              visible: root.keywords.trim() !== ""
              anchors.horizontalCenter: parent.horizontalCenter
              implicitHeight: Style.space(24)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
              borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)

              Row {
                anchors.centerIn: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰍉 " + root.keywords
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: Color.accent
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "✕"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(Color.popups.text, 1.4)
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.persistSettings({ keywords: "" }, true)
                  root.showToast("Cleared search filter")
                }
              }
            }
          }

          // ==========================================
          // SETTINGS VIEW COLUMN
          // ==========================================
          Column {
            id: settingsColumn
            visible: root.activeView === "SETTINGS"
            width: flickable.width - (flickable.contentHeight > flickable.height ? Style.space(12) : 0)
            spacing: Style.space(12)

            // 1. Color Mode Selector
            PanelSectionHeader {
              text: "COLOR MODE"
              foreground: Color.popups.text
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - Style.space(16)) / 3
                text: "Matching"
                iconText: "󰏘"
                selected: root.colorMode === "matching"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Directly match Wallhaven wallpapers to theme colors"
                onClicked: root.persistSettings({ colorMode: "matching" })
              }

              Button {
                width: (parent.width - Style.space(16)) / 3
                text: "Complementary"
                iconText: "󰽉"
                selected: root.colorMode === "complementary"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Find wallpapers with complementary (opposite) colors on the wheel"
                onClicked: root.persistSettings({ colorMode: "complementary" })
              }

              Button {
                width: (parent.width - Style.space(16)) / 3
                text: "Surprise Me"
                iconText: "󰒝"
                selected: root.colorMode === "surprise"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Random blend of matching and complementary palettes"
                onClicked: root.persistSettings({ colorMode: "surprise" })
              }
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(Color.popups.text, 1.4)
              text: {
                if (root.colorMode === "complementary")
                  return "Computes 180° complementary hues on the color wheel from your selected theme colors."
                if (root.colorMode === "surprise")
                  return "Blends matching and complementary palettes randomly per wallpaper rotation."
                return "Searches Wallhaven using your active theme colors directly."
              }
            }

            PanelSeparator {}

            // 1.5 Harmony Score Threshold
            PanelSectionHeader {
              text: "HARMONY SCORE THRESHOLD"
              foreground: Color.popups.text
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(Color.popups.text, 1.3)
              text: "Only keep wallpapers scoring at or below this limit. Lower = stricter color match."
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: [
                  { value: 0, label: "Off" },
                  { value: 15, label: "≤ 15" },
                  { value: 25, label: "≤ 25" },
                  { value: 35, label: "≤ 35" },
                  { value: 50, label: "≤ 50" }
                ]

                Button {
                  width: (parent.parent.width - Style.space(24)) / 5
                  text: modelData.label
                  bordered: true
                  selected: root.maxScore === modelData.value
                  foreground: Color.popups.text
                  accent: Color.accent
                  onClicked: root.persistSettings({ maxScore: modelData.value })
                }
              }
            }

            BorderSurface {
              visible: root.maxScore > 0
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.12)
              borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)
              padding: Style.space(8)

              Text {
                width: parent.width - Style.space(16)
                anchors.centerIn: parent
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.urgent
                text: {
                  var t = "⚠ A threshold of ≤ " + root.maxScore + " means only wallpapers with very "
                  if (root.maxScore <= 15) t += "close"
                  else if (root.maxScore <= 25) t += "strong"
                  else t += "moderate"
                  t += " theme matches will be kept. This may significantly reduce available results"
                  t += " — if too few wallpapers match, the filter relaxes automatically so you always get something."
                  return t
                }
              }
            }

            PanelSeparator {}

            // 2. Ranked Color Palette
            PanelSectionHeader {
              text: "RANKED THEME PALETTE"
              foreground: Color.popups.text
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(Color.popups.text, 1.3)
              text: "Left-click to toggle and rank. Right-click to make primary (#1)."
            }

            Flow {
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: root.paletteKeys

                BorderSurface {
                  id: colorChip
                  readonly property string colorKey: modelData
                  readonly property int rank: root.colorKeys.indexOf(colorKey) + 1
                  readonly property bool isActive: rank > 0
                  readonly property bool isPrimary: rank === 1
                  readonly property color resolvedColor: root.getHexForThemeKey(colorKey)

                  implicitWidth: Style.space(42)
                  implicitHeight: Style.space(42)
                  radius: Style.cornerRadius
                  color: colorChip.resolvedColor
                  opacity: colorChip.isActive ? 1.0 : (chipMouse.containsMouse ? 0.75 : 0.4)

                  borderSpec: colorChip.isPrimary
                    ? Border.flat(Color.accent, 2)
                    : (colorChip.isActive
                      ? Border.flat(Color.accent, 1)
                      : Border.flat(Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.2), 1))

                  Behavior on opacity { NumberAnimation { duration: 120 } }

                  // Numeric rank overlay badge
                  Rectangle {
                    visible: colorChip.isActive
                    anchors.centerIn: parent
                    width: Style.space(22)
                    height: Style.space(22)
                    radius: width / 2
                    color: colorChip.isPrimary ? Color.accent : Qt.rgba(0, 0, 0, 0.72)
                    border.width: 1
                    border.color: colorChip.isPrimary ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)

                    Text {
                      anchors.centerIn: parent
                      text: String(colorChip.rank)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: colorChip.isPrimary ? Color.popups.background : "#ffffff"
                    }
                  }

                  MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                      if (mouse.button === Qt.RightButton) {
                        root.setPrimaryColorKey(colorChip.colorKey)
                      } else {
                        root.toggleColorKey(colorChip.colorKey)
                      }
                    }
                  }

                  PanelToolTip {
                    visible: chipMouse.containsMouse
                    text: colorChip.colorKey + (colorChip.isActive ? (colorChip.isPrimary ? " (#1 Primary)" : " (#" + colorChip.rank + ")") : "")
                    fontFamily: Style.font.family
                  }
                }
              }
            }

            PanelSeparator {}

            // 3. Keywords & Content Filter
            PanelSectionHeader {
              text: "KEYWORDS & CONTENT FILTER"
              foreground: Color.popups.text
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                text: "Keywords (Wallhaven search query)"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Qt.darker(Color.popups.text, 1.4)
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(6)

                TextField {
                  id: keywordsField
                  Layout.fillWidth: true
                  text: root.keywords
                  placeholderText: "e.g. nature, mountains, cyberpunk, minimal"
                  foreground: Color.popups.text
                  accent: Color.accent

                  onActiveFocusChanged: {
                    root.editingKeywords = activeFocus
                  }

                  onAccepted: {
                    var kw = text.trim()
                    root.persistSettings({ keywords: kw }, true)
                    root.showToast(kw !== "" ? ("Searching for '" + kw + "'...") : "Searching theme wallpapers...")
                  }
                }

                Button {
                  text: cacheManager.isFetching ? "..." : "Search"
                  iconText: "󰍉"
                  bordered: true
                  accent: Color.accent
                  enabled: !cacheManager.isBusy
                  onClicked: {
                    var kw = keywordsField.text.trim()
                    root.persistSettings({ keywords: kw }, true)
                    root.showToast(kw !== "" ? ("Searching for '" + kw + "'...") : "Searching theme wallpapers...")
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                width: (parent.width - Style.space(8)) / 2
                label: "Category"
                value: root.category
                foreground: Color.popups.text
                background: Color.popups.background
                popupBorder: Color.popups.border
                accent: Color.accent
                options: [
                  { value: "general", label: "General" },
                  { value: "anime", label: "Anime" },
                  { value: "people", label: "People" },
                  { value: "general+anime", label: "General + Anime" },
                  { value: "all", label: "All Categories" }
                ]
                onChanged: function(v) { root.persistSettings({ category: v }) }
              }

              Dropdown {
                width: (parent.width - Style.space(8)) / 2
                label: "Content Filter"
                value: root.purity
                foreground: Color.popups.text
                background: Color.popups.background
                popupBorder: Color.popups.border
                accent: Color.accent
                options: [
                  { value: "sfw", label: "SFW (Safe for Work)" },
                  { value: "sfw+sketchy", label: "SFW + Sketchy" },
                  { value: "all", label: "All (SFW + Sketchy + NSFW)" }
                ]
                onChanged: function(v) { root.persistSettings({ purity: v }) }
              }
            }

            // Content Filter Warning
            BorderSurface {
              visible: root.purity === "all"
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
              borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)
              padding: Style.space(8)

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: "⚠"
                  font.pixelSize: Style.font.body
                  color: Color.urgent
                }

                Text {
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                  text: "Warning: Content filter allows sketchy and NSFW results from Wallhaven."
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.popups.text
                }
              }
            }

            PanelSeparator {}

            // 4. Rotation & Caching Settings
            PanelSectionHeader {
              text: "ROTATION & CACHING"
              foreground: Color.popups.text
            }

            Dropdown {
              width: parent.width
              label: "Rotation Interval"
              value: String(root.interval)
              foreground: Color.popups.text
              background: Color.popups.background
              popupBorder: Color.popups.border
              accent: Color.accent
              options: [
                { value: "300", label: "5 minutes ⚠" },
                { value: "900", label: "15 minutes" },
                { value: "1800", label: "30 minutes (Default)" },
                { value: "3600", label: "1 hour" },
                { value: "7200", label: "2 hours" },
                { value: "14400", label: "4 hours" }
              ]
              onChanged: function(v) { root.persistSettings({ interval: parseInt(v, 10) }) }
            }

            // 5-minute Rate Limit Warning Box
            BorderSurface {
              visible: root.interval <= 300
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
              borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)
              padding: Style.space(8)

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: "⚠"
                  font.pixelSize: Style.font.body
                  color: Color.urgent
                }

                Text {
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                  text: "Short intervals may approach Wallhaven's 45 requests/minute limit, especially in live-fetch mode (which hits the API every tick). If you experience errors, increase the interval or switch to pre-fetch mode."
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.popups.text
                }
              }
            }

            Toggle {
              width: parent.width
              label: "Pre-fetch Mode"
              description: root.fetchMode === "prefetch"
                ? ("Downloads batches of " + root.prefetchCount + " wallpapers in advance to rotate smoothly from local cache.")
                : "Live fetch: queries Wallhaven and downloads a new image on every rotation tick."
              checked: root.fetchMode === "prefetch"
              foreground: Color.popups.text
              accent: Color.accent
              onClicked: root.persistSettings({ fetchMode: root.fetchMode === "prefetch" ? "live" : "prefetch" })
            }

            // Pre-fetch count pills
            Row {
              visible: root.fetchMode === "prefetch"
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Batch Size:"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Qt.darker(Color.popups.text, 1.4)
              }

              Repeater {
                model: [5, 10, 15, 20]

                Button {
                  text: String(modelData)
                  selected: root.prefetchCount === modelData
                  bordered: true
                  foreground: Color.popups.text
                  accent: Color.accent
                  onClicked: root.persistSettings({ prefetchCount: modelData })
                }
              }
            }

            Toggle {
              width: parent.width
              label: "Multi-Monitor"
              description: root.multiMonitor === "same"
                ? "Displays the same wallpaper across all connected displays."
                : "Sets independent wallpapers per display from cache."
              checked: root.multiMonitor === "different"
              foreground: Color.popups.text
              accent: Color.accent
              onClicked: root.persistSettings({ multiMonitor: root.multiMonitor === "different" ? "same" : "different" })
            }

            Toggle {
              width: parent.width
              label: "Save Behavior"
              description: root.saveBehavior === "rotate"
                ? "Save & Rotate: adds wallpaper to backgrounds/ (joins regular Super+Ctrl+Space rotation)."
                : "Save Only: saves wallpaper to saved-wallpapers/ without joining theme rotation."
              checked: root.saveBehavior === "rotate"
              foreground: Color.popups.text
              accent: Color.accent
              onClicked: root.persistSettings({ saveBehavior: root.saveBehavior === "rotate" ? "save_only" : "rotate" })
            }

            Toggle {
              width: parent.width
              label: "Allow Repeating Wallpapers"
              description: root.allowDuplicates
                ? "Duplicate wallpapers permitted across rotations."
                : "Wallhaven IDs recorded in history.json to ensure fresh wallpapers."
              checked: root.allowDuplicates
              foreground: Color.popups.text
              accent: Color.accent
              onClicked: root.persistSettings({ allowDuplicates: !root.allowDuplicates })
            }

            PanelSeparator {}

            // 5. Bar Placement (Left, Center, Right)
            PanelSectionHeader {
              text: "BAR PLACEMENT"
              foreground: Color.popups.text
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(Color.popups.text, 1.3)
              text: "Position the Chromarchy widget on your status bar."
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - Style.space(16)) / 3
                text: "Left"
                iconText: "󰄱"
                selected: root.currentBarSection === "left"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Move Chromarchy to the left bar section"
                onClicked: root.moveBarSection("left")
              }

              Button {
                width: (parent.width - Style.space(16)) / 3
                text: "Center"
                iconText: "󰄵"
                selected: root.currentBarSection === "center"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Move Chromarchy to the center bar section"
                onClicked: root.moveBarSection("center")
              }

              Button {
                width: (parent.width - Style.space(16)) / 3
                text: "Right"
                iconText: "󰄲"
                selected: root.currentBarSection === "right"
                bordered: true
                foreground: Color.popups.text
                accent: Color.accent
                tooltipText: "Move Chromarchy to the right bar section"
                onClicked: root.moveBarSection("right")
              }
            }

            PanelSeparator {}

            // 5. Footer (Cache stats & reset)
            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Text {
                Layout.fillWidth: true
                text: "Cache: " + root.cachedCount + " wallpapers • History: " + root.historyCount + " seen"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.darker(Color.popups.text, 1.4)
              }

              Button {
                text: "Clear Cache"
                iconText: "󰃢"
                bordered: true
                foreground: Color.urgent
                accent: Color.urgent
                tooltipText: "Delete cached wallpaper files and clear history"
                onClicked: root.clearCache()
              }
            }
          }
        }
      }
    }
  }
}
