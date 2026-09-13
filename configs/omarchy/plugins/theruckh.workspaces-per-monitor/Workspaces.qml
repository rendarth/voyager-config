import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Multi-monitor Hyprland workspace switcher.
//
// By default each bar surface only shows the workspaces that belong to its
// own monitor, so a two-monitor setup doesn't repeat the same 1-10 list on
// every screen. Behavior is tunable through the widget's `settings` block in
// ~/.config/omarchy/shell.json:
//
//   "id": "theruckh.workspaces-per-monitor",
//   "settings": {
//     "perMonitor": true,   // only this monitor's workspaces (default true)
//     "limit": 0,           // max workspaces in the fixed list (0 = no limit)
//     "dynamicStart": 0     // collapse workspaces >= this id into a single slot
//   }
//
// When dynamicStart > 0, workspaces from that id upward collapse into one
// trailing button that shows whichever of them is currently active (or the
// highest occupied). This keeps the bar compact when you have many workspaces.

BarWidget {
  id: root
  moduleName: "theruckh.workspaces-per-monitor"

  // ---------- configuration (read from shell.json settings) ----------
  readonly property bool perMonitor: root.setting("perMonitor", true)
  readonly property int limit: root.setting("limit", 0)
  readonly property int dynamicStart: root.setting("dynamicStart", 0)

  // ---------- workspace helpers ----------
  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  // Output name of the monitor this bar surface is rendered on. The widget
  // has no direct window handle, so match its global position against each
  // Quickshell screen's geometry (x/y/width/height).
  function monitorName() {
    if (typeof Quickshell === "undefined") return ""
    var pt = root.mapToGlobal(root.x, root.y)
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      var sc = screens[i]
      if (pt.x >= sc.x && pt.x < sc.x + sc.width && pt.y >= sc.y && pt.y < sc.y + sc.height) {
        return String(sc.name || "")
      }
    }
    return ""
  }

  // All positive workspace ids on this monitor (or all, if perMonitor is off),
  // sorted ascending.
  function monitorWorkspaceIds() {
    var mon = root.monitorName()
    var ids = []
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      if (!w || w.id <= 0) continue
      if (root.perMonitor) {
        var wmon = w.monitor ? String(w.monitor.name || "") : ""
        if (wmon !== mon) continue
      }
      ids.push(w.id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // Fixed list shown as one button per workspace. Skips the dynamic range and
  // obeys `limit`.
  function baseWorkspaceIds() {
    var all = root.monitorWorkspaceIds()
    var out = []
    for (var i = 0; i < all.length; i++) {
      if (root.dynamicStart > 0 && all[i] >= root.dynamicStart) continue
      out.push(all[i])
    }
    if (root.limit > 0 && out.length > root.limit) {
      out = out.slice(0, root.limit)
    }
    return out
  }

  // The workspace in the dynamic range (>= dynamicStart) currently in use:
  // prefers the active one, otherwise the highest occupied. 0 when none.
  function dynamicWorkspaceId() {
    if (root.dynamicStart <= 0) return 0
    var all = root.monitorWorkspaceIds()
    var activeId = 0
    var highestOccupied = 0
    for (var i = 0; i < all.length; i++) {
      var id = all[i]
      if (id < root.dynamicStart) continue
      var w = root.workspaceById(id)
      if (!w) continue
      var occupied = w.toplevels && w.toplevels.values && w.toplevels.values.length > 0
      if (occupied && id > highestOccupied) highestOccupied = id
      if (w.active && id > activeId) activeId = id
    }
    if (activeId) return activeId
    return highestOccupied
  }

  // ---------- focus ----------
  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---------- layout ----------
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1
      : (root.baseWorkspaceIds().length + (root.dynamicWorkspaceId() > 0 ? 1 : 0))
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.baseWorkspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }

    // Optional single trailing slot for the dynamic range (e.g. 6-9).
    WidgetButton {
      visible: root.dynamicStart > 0 && root.dynamicWorkspaceId() > 0

      readonly property int extId: root.dynamicWorkspaceId()
      readonly property var extWorkspace: extId > 0 ? root.workspaceById(extId) : null
      readonly property bool extFocused: extId > 0 && Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === extId
      readonly property bool extOccupied: extWorkspace !== null && extWorkspace.toplevels.values.length > 0

      bar: root.bar
      text: extFocused ? "\uDB85\uDCFB" : String(extId)
      opacity: extOccupied || extFocused ? 1 : 0.5
      horizontalMargin: 6
      verticalPadding: 6
      fixedWidth: root.vertical ? root.barSize : Style.space(20)
      fixedHeight: root.barSize
      onPressed: function() { root.focusWorkspace(extId) }
    }
  }
}
