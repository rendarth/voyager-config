import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "FullscreenWorkspace.js" as Logic

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id)
    : "io.github.danbosscher.fullscreen-workspace"
  readonly property var pluginSettings: root.readPluginSettings()
  readonly property int targetWorkspace: Logic.workspaceNumber(pluginSettings.workspace, 9)
  readonly property bool returnOnExit: Logic.booleanSetting(pluginSettings.returnOnExit, true)
  readonly property bool followOnEnter: Logic.booleanSetting(pluginSettings.followOnEnter, true)
  readonly property bool followOnExit: Logic.booleanSetting(pluginSettings.followOnExit, true)
  readonly property bool moveExistingOnStart: Logic.booleanSetting(pluginSettings.moveExistingOnStart, false)
  readonly property bool moveFromSpecialWorkspaces: Logic.booleanSetting(pluginSettings.moveFromSpecialWorkspaces, false)
  readonly property var extraExcludedClasses: Logic.normalizedStringList(pluginSettings.excludedClasses)
  readonly property var excludedClasses: Logic.mergedStringLists(
    ["org.omarchy.screensaver"], extraExcludedClasses)

  property var fullscreenStates: ({})
  property var origins: ({})
  property bool initialized: false
  property string lastEvent: "starting"
  property string lastError: ""

  function readPluginSettings() {
    var config = shell ? shell.shellConfig : null
    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (entry && String(entry.id || "") === root.pluginId) return entry
    }
    return ({})
  }

  function editablePluginSettings() {
    var current = root.readPluginSettings()
    var copy = { id: root.pluginId }
    for (var key in current) if (key !== "id") copy[key] = current[key]
    return copy
  }

  function persistSetting(key, value, defaultValue) {
    if (!root.shell || typeof root.shell.updateEntryInline !== "function") return "shell-unavailable"
    var settings = root.editablePluginSettings()
    if (JSON.stringify(value) === JSON.stringify(defaultValue)) delete settings[key]
    else settings[key] = value
    root.shell.updateEntryInline(root.pluginId, settings)
    return "ok"
  }

  function resetSettings() {
    if (!root.shell || typeof root.shell.updateEntryInline !== "function") return "shell-unavailable"
    root.shell.updateEntryInline(root.pluginId, {})
    return "ok"
  }

  function normalizedAddress(toplevel) {
    return Logic.normalizeAddress(toplevel ? toplevel.address : "")
  }

  function workspaceName(toplevel) {
    if (!toplevel || !toplevel.workspace) return ""
    var name = String(toplevel.workspace.name || "").trim()
    if (name) return name
    var id = Number(toplevel.workspace.id)
    return isFinite(id) ? String(id) : ""
  }

  function classCandidates(toplevel) {
    var result = []
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : null
    if (ipc) {
      if (ipc.class !== undefined) result.push(String(ipc.class))
      if (ipc.initialClass !== undefined) result.push(String(ipc.initialClass))
      if (ipc.initial_class !== undefined) result.push(String(ipc.initial_class))
    }
    if (toplevel && toplevel.wayland && toplevel.wayland.appId)
      result.push(String(toplevel.wayland.appId))
    return Logic.normalizedStringList(result)
  }

  function isTrueFullscreen(toplevel) {
    var ipc = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : null
    if (ipc && Logic.isTrueFullscreenMode(ipc.fullscreen)) return true
    return !!(toplevel && toplevel.wayland && toplevel.wayland.fullscreen)
  }

  function shouldIgnore(toplevel, workspace) {
    if (!root.moveFromSpecialWorkspaces && Logic.isSpecialWorkspace(workspace)) return true
    return Logic.isExcluded(root.classCandidates(toplevel), root.excludedClasses)
  }

  function copyWithout(source, removedKey) {
    var copy = ({})
    for (var key in source) if (key !== removedKey) copy[key] = source[key]
    return copy
  }

  function setOrigin(address, workspace) {
    var next = ({})
    for (var key in root.origins) next[key] = root.origins[key]
    next[address] = workspace
    root.origins = next
  }

  function takeOrigin(address) {
    var origin = root.origins[address]
    if (origin !== undefined) root.origins = root.copyWithout(root.origins, address)
    return origin === undefined ? "" : String(origin)
  }

  function dispatchMove(address, workspace, follow) {
    var normalized = Logic.normalizeAddress(address)
    var destination = String(workspace || "").trim()
    if (!normalized || !destination) return false

    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.move({ workspace = " + Logic.luaString(destination)
        + ", window = " + Logic.luaString("address:" + normalized)
        + ", follow = " + (follow ? "true" : "false") + " })")
    } else {
      Hyprland.dispatch((follow ? "movetoworkspace " : "movetoworkspacesilent ")
        + destination + ",address:" + normalized)
    }
    return true
  }

  function handleFullscreenEntered(toplevel) {
    var address = root.normalizedAddress(toplevel)
    var sourceWorkspace = root.workspaceName(toplevel)
    var destination = String(root.targetWorkspace)
    if (!address || !sourceWorkspace || sourceWorkspace === destination) return
    if (root.shouldIgnore(toplevel, sourceWorkspace)) return

    root.setOrigin(address, sourceWorkspace)
    if (root.dispatchMove(address, destination, root.followOnEnter)) {
      root.lastError = ""
      root.lastEvent = "entered " + sourceWorkspace + " -> " + destination
    }
  }

  function handleFullscreenExited(toplevel) {
    var address = root.normalizedAddress(toplevel)
    if (!address) return
    var origin = root.takeOrigin(address)
    if (!origin) return

    if (!root.returnOnExit) {
      root.lastEvent = "fullscreen ended; kept on dedicated workspace"
      return
    }
    if (root.dispatchMove(address, origin, root.followOnExit)) {
      root.lastError = ""
      root.lastEvent = "exited -> " + origin
    }
  }

  function reconcileToplevels() {
    var values = Hyprland.toplevels && Hyprland.toplevels.values
      ? Hyprland.toplevels.values
      : []
    var nextStates = ({})
    var liveAddresses = ({})

    for (var i = 0; i < values.length; i++) {
      var toplevel = values[i]
      var address = root.normalizedAddress(toplevel)
      if (!address) continue

      var fullscreen = root.isTrueFullscreen(toplevel)
      var wasFullscreen = !!root.fullscreenStates[address]
      nextStates[address] = fullscreen
      liveAddresses[address] = true

      if (!root.initialized) {
        if (root.moveExistingOnStart && fullscreen) root.handleFullscreenEntered(toplevel)
      } else if (fullscreen && !wasFullscreen) {
        root.handleFullscreenEntered(toplevel)
      } else if (!fullscreen && wasFullscreen) {
        root.handleFullscreenExited(toplevel)
      }
    }

    var keptOrigins = ({})
    for (var key in root.origins)
      if (liveAddresses[key]) keptOrigins[key] = root.origins[key]

    root.origins = keptOrigins
    root.fullscreenStates = nextStates
    root.initialized = true
    if (root.lastEvent === "starting") root.lastEvent = "ready"
  }

  function requestReconcile() {
    Hyprland.refreshToplevels()
    reconcileTimer.restart()
  }

  function forgetWindow(address) {
    var normalized = Logic.normalizeAddress(address)
    if (!normalized) return
    root.fullscreenStates = root.copyWithout(root.fullscreenStates, normalized)
    root.origins = root.copyWithout(root.origins, normalized)
  }

  function trackedCount() {
    var count = 0
    for (var key in root.origins) count++
    return count
  }

  function statusJson() {
    return JSON.stringify({
      initialized: root.initialized,
      workspace: root.targetWorkspace,
      returnOnExit: root.returnOnExit,
      followOnEnter: root.followOnEnter,
      followOnExit: root.followOnExit,
      moveExistingOnStart: root.moveExistingOnStart,
      moveFromSpecialWorkspaces: root.moveFromSpecialWorkspaces,
      excludedClasses: root.excludedClasses,
      trackedWindows: root.trackedCount(),
      lastEvent: root.lastEvent,
      lastError: root.lastError
    })
  }

  Timer {
    id: reconcileTimer
    interval: 80
    repeat: false
    onTriggered: root.reconcileToplevels()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "fullscreen" || name === "openwindow") {
        root.requestReconcile()
      } else if (name === "closewindow") {
        var parts = event.parse(1)
        root.forgetWindow(parts && parts.length > 0 ? parts[0] : event.data)
      }
    }
  }

  Component.onCompleted: root.requestReconcile()

  IpcHandler {
    target: "fullscreen-workspace"

    function status(): string {
      return root.statusJson()
    }

    function setWorkspace(value: string): string {
      var workspace = Logic.workspaceNumber(value, -1)
      if (workspace < 1) return "expected a workspace number from 1 to 10"
      return root.persistSetting("workspace", workspace, 9)
    }

    function setReturnOnExit(value: string): string {
      var parsed = Logic.parsedBoolean(value)
      if (!parsed.valid) return "expected true or false"
      return root.persistSetting("returnOnExit", parsed.value, true)
    }

    function setFollowOnEnter(value: string): string {
      var parsed = Logic.parsedBoolean(value)
      if (!parsed.valid) return "expected true or false"
      return root.persistSetting("followOnEnter", parsed.value, true)
    }

    function setFollowOnExit(value: string): string {
      var parsed = Logic.parsedBoolean(value)
      if (!parsed.valid) return "expected true or false"
      return root.persistSetting("followOnExit", parsed.value, true)
    }

    function setMoveExistingOnStart(value: string): string {
      var parsed = Logic.parsedBoolean(value)
      if (!parsed.valid) return "expected true or false"
      return root.persistSetting("moveExistingOnStart", parsed.value, false)
    }

    function setMoveFromSpecialWorkspaces(value: string): string {
      var parsed = Logic.parsedBoolean(value)
      if (!parsed.valid) return "expected true or false"
      return root.persistSetting("moveFromSpecialWorkspaces", parsed.value, false)
    }

    function setExcludedClasses(value: string): string {
      return root.persistSetting("excludedClasses", Logic.commaSeparatedList(value), [])
    }

    function reset(): string {
      return root.resetSettings()
    }
  }
}
