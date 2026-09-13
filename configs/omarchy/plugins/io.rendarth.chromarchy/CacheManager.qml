import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  // Paths
  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string cacheDir: home + "/.cache/chromarchy"
  readonly property string wallpapersDir: cacheDir + "/wallpapers"
  readonly property string historyPath: cacheDir + "/history.json"
  readonly property string currentBatchPath: cacheDir + "/current_batch.json"
  readonly property string savedWallpapersDir: home + "/.config/omarchy/saved-wallpapers"
  readonly property string backgroundsDir: home + "/.config/omarchy/backgrounds"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"

  // Settings & Configuration
  property string colorMode: "matching"           // "matching" | "complementary" | "surprise"
  property var colorKeys: ["accent", "background"]// Array of theme color keys
  property string keywords: ""                    // Free text search query
  property string category: "general"             // "general" | "anime" | "people" | "general+anime" | "all"
  property string purity: "sfw"                   // "sfw" | "sketchy" | "sfw+sketchy" | "all"
  property string fetchMode: "prefetch"           // "prefetch" | "live"
  property int prefetchCount: 10                  // 1 to 20
  property int interval: 1800                     // Seconds between rotations
  property string multiMonitor: "same"            // "same" | "different"
  property string saveBehavior: "rotate"          // "rotate" | "save-only"
  property bool allowDuplicates: false            // Allow previously seen wallpapers
  property int maxScore: 0                         // Maximum harmony score (0 = no limit)

  // State
  property string state: "idle"                   // "idle" | "fetching" | "downloading" | "applying" | "error"
  readonly property bool isBusy: state === "fetching" || state === "downloading" || state === "applying"
  readonly property bool isFetching: state === "fetching"
  readonly property bool isDownloading: state === "downloading"
  property bool hasError: false
  property string errorMessage: ""
  property string statusText: "Ready"
  property bool isPaused: false
  readonly property bool shortIntervalWarning: interval <= 300

  // Active Wallpaper and Batch Models
  property var currentWallpaper: null
  property var currentBatch: []
  property int currentIndex: -1
  property var history: []
  property string detectedResolution: "1920x1080"
  property string activeThemeName: "default"

  // Download queue internals
  property var downloadQueue: []
  property int downloadIndex: 0
  property var buildingBatch: []
  property var searchCandidatePool: []

  // Subcomponents
  readonly property ColorUtils colorUtils: colorUtilsItem
  readonly property WallhavenApi api: apiItem

  // Signals
  signal wallpaperApplied(var wallpaper)
  signal wallpaperSaved(string targetPath, string mode)
  signal batchLoaded(var batch)
  signal errorOccurred(string message)

  ColorUtils {
    id: colorUtilsItem
  }

  WallhavenApi {
    id: apiItem

    onSearchSuccess: function(wallpapers, meta, params) {
      root.handleSearchSuccess(wallpapers, meta, params)
    }

    onSearchFailed: function(error, statusCode) {
      root.handleSearchFailed(error, statusCode)
    }

    onDownloadSuccess: function(wpId, localPath) {
      root.handleDownloadSuccess(wpId, localPath)
    }

    onDownloadFailed: function(wpId, error) {
      root.handleDownloadFailed(wpId, error)
    }
  }

  // Bitmask normalization helpers
  function normalizeCategory(cat) {
    var c = String(cat || "general").toLowerCase()
    if (c === "general") return "100"
    if (c === "anime") return "010"
    if (c === "people") return "001"
    if (c === "general+anime" || c === "general_anime" || c === "anime+general") return "110"
    if (c === "all" || c === "111") return "111"
    if (/^[01]{3}$/.test(c)) return c
    return "100"
  }

  function normalizePurity(pur) {
    var p = String(pur || "sfw").toLowerCase()
    if (p === "sfw") return "100"
    if (p === "sketchy") return "010"
    if (p === "sfw+sketchy" || p === "sketchy+sfw" || p === "sfw_sketchy") return "110"
    if (p === "all" || p === "nsfw" || p === "111") return "111"
    if (/^[01]{3}$/.test(p)) return p
    return "100"
  }

  // Primary Fetch Pipeline
  function fetchBatch(page) {
    var targetPage = page || 1
    if (targetPage === 1) {
      root.searchCandidatePool = []
    }
    
    if (root.api.isRateLimited) {
      root.state = "error"
      root.hasError = true
      root.errorMessage = "Rate limited by Wallhaven. Cooldown: " + root.api.rateLimitCooldownRemaining + "s"
      root.statusText = root.errorMessage
      root.errorOccurred(root.errorMessage)
      return
    }

    root.state = "fetching"
    root.hasError = false
    root.errorMessage = ""
    root.statusText = targetPage > 1 ? "Searching Wallhaven deeper (Page " + targetPage + ")..." : "Searching Wallhaven for theme wallpapers..."

    var resolvedColors = colorUtilsItem.resolveThemeColors(root.colorKeys)
    var searchColor = colorUtilsItem.getSearchColor(resolvedColors, root.colorMode)
    var categories = normalizeCategory(root.category)
    var purity = normalizePurity(root.purity)
    var resolution = root.detectedResolution || "1920x1080"

    root.api.search({
      color: searchColor,
      keywords: root.keywords,
      categories: categories,
      purity: purity,
      resolution: resolution,
      page: targetPage
    })
  }

  // Handle Search Results
  function handleSearchSuccess(wallpapers, meta, params) {
    if (!wallpapers || wallpapers.length === 0) {
      root.state = "error"
      root.hasError = true
      root.errorMessage = "No wallpapers found matching current theme or keywords"
      root.statusText = "No results found"
      root.errorOccurred(root.errorMessage)
      return
    }

    // Deduplication via history.json
    var candidates = []
    if (!root.allowDuplicates && root.history && root.history.length > 0) {
      for (var i = 0; i < wallpapers.length; i++) {
        if (root.history.indexOf(wallpapers[i].id) === -1) {
          candidates.push(wallpapers[i])
        }
      }

      // If all results have already been seen, reset history cycle
      if (candidates.length === 0) {
        console.log("chromarchy: All matching wallpapers seen in history. Resetting history cycle.")
        root.clearHistory()
        candidates = wallpapers
        root.statusText = "History cycle complete; resetting duplicate filter"
      }
    } else {
      candidates = wallpapers
    }

    // Score candidates against selected theme colors
    var resolvedColors = colorUtilsItem.resolveThemeColors(root.colorKeys)
    var newScored = colorUtilsItem.sortWallpapers(candidates, resolvedColors)

    // Accumulate into the global pool across pages
    var pool = root.searchCandidatePool || []
    for (var k = 0; k < newScored.length; k++) {
      pool.push(newScored[k])
    }
    pool.sort(function(a, b) { return a.score - b.score })
    root.searchCandidatePool = pool

    var currentPage = params && params.page ? parseInt(params.page, 10) : 1
    var lastPage = meta && meta.last_page ? parseInt(meta.last_page, 10) : 5
    var maxSearchPages = 5
    var finalCandidates = pool

    // Apply harmony score threshold filter (if set)
    if (root.maxScore > 0 && pool.length > 0) {
      var filtered = []
      for (var j = 0; j < pool.length; j++) {
        if (pool[j].score !== undefined && pool[j].score <= root.maxScore) {
          filtered.push(pool[j])
        }
      }

      if (filtered.length > 0) {
        finalCandidates = filtered
        console.log("chromarchy: Score threshold " + root.maxScore + " kept " + finalCandidates.length + " wallpapers (from " + pool.length + " total)")
      } else {
        if (currentPage < Math.min(lastPage, maxSearchPages)) {
          console.log("chromarchy: Score threshold " + root.maxScore + " filtered ALL results up to page " + currentPage + ". Fetching next page.")
          root.statusText = "Looking deeper... (Page " + (currentPage + 1) + ")"
          fetchBatch(currentPage + 1)
          return
        } else {
          console.log("chromarchy: Score threshold " + root.maxScore + " filtered ALL results on all attempted pages. Using best available from pool.")
          root.statusText = "No wallpapers under score " + root.maxScore + "; showing best available"
          finalCandidates = pool // Fall back to the absolute best out of all pages fetched
        }
      }
    }

    // Determine target download count
    var count = (root.fetchMode === "live") ? 1 : Math.min(root.prefetchCount, finalCandidates.length)
    root.downloadQueue = finalCandidates.slice(0, count)
    root.downloadIndex = 0
    root.buildingBatch = []

    if (root.downloadQueue.length === 0) {
      root.state = "error"
      root.hasError = true
      root.errorMessage = "No eligible wallpapers to download"
      root.statusText = "No eligible wallpapers"
      return
    }

    root.state = "downloading"
    root.statusText = "Downloading wallpaper 1 of " + root.downloadQueue.length + "..."
    downloadNextInQueue()
  }

  // Download next item from queue
  function downloadNextInQueue() {
    if (root.downloadIndex >= root.downloadQueue.length) {
      finishBatchDownload()
      return
    }

    var item = root.downloadQueue[root.downloadIndex]
    var ext = "jpg"
    if (item.path && item.path.indexOf(".png") !== -1) ext = "png"
    var targetPath = root.wallpapersDir + "/wallhaven-" + item.id + "." + ext

    root.statusText = "Downloading " + (root.downloadIndex + 1) + "/" + root.downloadQueue.length + " (" + item.id + ")..."
    root.api.download(item, targetPath, root.detectedResolution)
  }

  // Handle Download Success
  function handleDownloadSuccess(wpId, localPath) {
    if (root.downloadIndex < root.downloadQueue.length) {
      var item = Object.assign({}, root.downloadQueue[root.downloadIndex])
      item.localFile = localPath
      root.buildingBatch.push(item)

      // Apply first wallpaper immediately without waiting for rest of batch
      if (root.buildingBatch.length === 1) {
        root.applyWallpaper(item)
      }
    }

    root.downloadIndex += 1
    if (root.downloadIndex < root.downloadQueue.length) {
      downloadNextInQueue()
    } else {
      finishBatchDownload()
    }
  }

  // Handle Download Failure
  function handleDownloadFailed(wpId, error) {
    console.warn("chromarchy: Download failed for", wpId, error)

    // Move to next in queue
    root.downloadIndex += 1
    if (root.downloadIndex < root.downloadQueue.length) {
      downloadNextInQueue()
    } else {
      if (root.buildingBatch.length > 0) {
        finishBatchDownload()
      } else {
        root.state = "error"
        root.hasError = true
        root.errorMessage = "Wallpaper download failed: " + error
        root.statusText = "Download failed"
        root.errorOccurred(root.errorMessage)
      }
    }
  }

  // Finalize batch
  function finishBatchDownload() {
    if (root.buildingBatch.length > 0) {
      root.currentBatch = root.buildingBatch
      root.currentIndex = 0
      flushCurrentBatch()
      root.state = "idle"
      root.hasError = false
      root.statusText = "Ready (" + root.currentBatch.length + " cached)"
      root.batchLoaded(root.currentBatch)
    } else {
      root.state = "error"
      root.hasError = true
      root.errorMessage = "No wallpapers downloaded"
      root.statusText = "Download failed"
    }
  }

  // Apply Wallpaper to Desktop
  function applyWallpaper(item) {
    if (!item || !item.localFile) return

    root.currentWallpaper = item
    root.state = "applying"
    root.statusText = "Applying wallpaper..."

    bgSetProc.command = ["omarchy-theme-bg-set", item.localFile]
    bgSetProc.running = true

    // Track in history
    if (item.id && (!root.history || root.history.indexOf(item.id) === -1)) {
      var nextHistory = (root.history || []).slice(0)
      nextHistory.push(item.id)
      root.history = nextHistory
      flushHistory()
    }

    root.wallpaperApplied(item)
  }

  // Process runner for omarchy-theme-bg-set
  Process {
    id: bgSetProc
    running: false
    onExited: function(exitCode, exitStatus) {
      root.state = "idle"
      if (exitCode === 0) {
        root.statusText = "Wallpaper active: " + ((root.currentWallpaper && root.currentWallpaper.id) || "")
      } else {
        root.hasError = true
        root.errorMessage = "Failed to set wallpaper via omarchy-theme-bg-set (code " + exitCode + ")"
        root.statusText = root.errorMessage
      }
    }
  }

  // Rotate to next wallpaper
  function nextWallpaper() {
    if (root.isBusy) return

    if (root.fetchMode === "live") {
      fetchBatch()
      return
    }

    if (!root.currentBatch || root.currentBatch.length === 0) {
      fetchBatch()
      return
    }

    var nextIdx = root.currentIndex + 1
    if (nextIdx >= root.currentBatch.length) {
      // Current prefetch batch exhausted, fetch fresh batch
      fetchBatch()
      return
    }

    root.currentIndex = nextIdx
    applyWallpaper(root.currentBatch[root.currentIndex])
  }

  // Rotate to previous wallpaper
  function prevWallpaper() {
    if (root.isBusy) return
    if (!root.currentBatch || root.currentBatch.length === 0) return

    var prevIdx = root.currentIndex - 1
    if (prevIdx < 0) {
      prevIdx = root.currentBatch.length - 1
    }
    root.currentIndex = prevIdx
    applyWallpaper(root.currentBatch[root.currentIndex])
  }

  // Save current wallpaper to backgrounds or saved-wallpapers directory
  function saveCurrentWallpaper(behavior) {
    var mode = behavior || root.saveBehavior || "rotate"
    if (!root.currentWallpaper || !root.currentWallpaper.localFile) {
      root.statusText = "No active wallpaper to save"
      return
    }

    var src = root.currentWallpaper.localFile
    var theme = root.activeThemeName || "default"

    saveProc.stdoutText = ""
    saveProc.stderrText = ""
    saveProc.pendingMode = mode
    saveProc.command = [
      "bash",
      pluginDir + "/scripts/save-wallpaper.sh",
      "--file", src,
      "--behavior", mode,
      "--theme", theme
    ]
    saveProc.running = true
  }

  // Process runner for save-wallpaper.sh
  Process {
    id: saveProc
    running: false
    property string stdoutText: ""
    property string stderrText: ""
    property string pendingMode: "rotate"

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: saveProc.stdoutText = (text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: saveProc.stderrText = (text || "").trim()
    }

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var savedPath = saveProc.stdoutText
        var label = (saveProc.pendingMode === "rotate") ? "theme rotation" : "saved wallpapers"
        root.statusText = "Wallpaper saved to " + label + "!"
        root.wallpaperSaved(savedPath, saveProc.pendingMode)
      } else {
        root.statusText = "Failed to save wallpaper: " + (saveProc.stderrText || ("exit code " + exitCode))
      }
    }
  }

  // Rotation Timer
  Timer {
    id: rotationTimer
    interval: Math.max(10, root.interval) * 1000
    repeat: true
    running: !root.isPaused && root.interval > 0
    onTriggered: {
      root.nextWallpaper()
    }
  }

  // Toggle rotation pause
  function togglePause() {
    root.isPaused = !root.isPaused
    root.statusText = root.isPaused ? "Rotation paused" : "Rotation resumed"
  }

  // Clear seen history
  function clearHistory() {
    root.history = []
    flushHistory()
  }

  // Persistence: History File
  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (Array.isArray(parsed)) root.history = parsed
      } catch (e) {
        root.history = []
      }
    }
    onLoadFailed: {
      root.history = []
    }
  }

  function flushHistory() {
    try {
      historyFile.setText(JSON.stringify(root.history, null, 2) + "\n")
    } catch (e) {
      console.warn("chromarchy: Failed to flush history:", e)
    }
  }

  // Persistence: Current Batch File
  FileView {
    id: currentBatchFile
    path: root.currentBatchPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (Array.isArray(parsed) && parsed.length > 0) {
          root.currentBatch = parsed
          if (root.currentIndex < 0) {
            root.currentIndex = 0
            root.currentWallpaper = parsed[0]
          }
        }
      } catch (e) {
        root.currentBatch = []
      }
    }
    onLoadFailed: {
      root.currentBatch = []
    }
  }

  function flushCurrentBatch() {
    try {
      currentBatchFile.setText(JSON.stringify(root.currentBatch, null, 2) + "\n")
    } catch (e) {
      console.warn("chromarchy: Failed to flush current batch:", e)
    }
  }

  // Active theme name watcher
  FileView {
    id: themeNameFile
    path: root.themeNamePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      var name = (text() || "").trim()
      if (name) root.activeThemeName = name
    }
  }

  // Detect resolution via script / screens
  Process {
    id: detectResProc
    running: false
    command: ["bash", pluginDir + "/scripts/detect-resolution.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var res = (text || "").trim()
        if (/^\d+x\d+$/.test(res)) {
          root.detectedResolution = res
        }
      }
    }
  }

  // Directory initialization process
  Process {
    id: ensureDirsProc
    running: false
    command: ["mkdir", "-p", root.wallpapersDir, root.savedWallpapersDir, root.backgroundsDir]
    onExited: function(code) {
      historyFile.reload()
      currentBatchFile.reload()
      themeNameFile.reload()
      detectResProc.running = true

      // If no wallpaper active and not busy, initial fetch
      Qt.callLater(function() {
        if (!root.currentWallpaper && (!root.currentBatch || root.currentBatch.length === 0)) {
          root.fetchBatch()
        }
      })
    }
  }

  // Theme Change Listener
  Connections {
    target: Color
    function onAccentChanged() {
      themeChangeDebounceTimer.restart()
    }
  }

  Timer {
    id: themeChangeDebounceTimer
    interval: 500
    repeat: false
    onTriggered: {
      console.log("chromarchy: Theme change detected, updating palette and refreshing wallpapers...")
      colorUtilsItem.reloadTheme()
      themeNameFile.reload()
      root.currentBatch = []
      root.currentIndex = -1
      root.fetchBatch()
    }
  }

  Component.onCompleted: {
    // Initial auto-detection from screens if available
    var screens = Quickshell.screens || []
    if (screens.length > 0 && screens[0].width > 0 && screens[0].height > 0) {
      root.detectedResolution = Math.round(screens[0].width) + "x" + Math.round(screens[0].height)
    }
    ensureDirsProc.running = true
  }
}
