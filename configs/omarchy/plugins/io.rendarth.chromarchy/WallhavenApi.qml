import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Plugin base directory path
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")

  // Base API endpoint
  readonly property string baseUrl: "https://wallhaven.cc/api/v1/search"

  // State flags
  property bool searching: false
  property bool downloading: false
  readonly property bool busy: searching || downloading

  // Error & Status
  property string lastError: ""
  property int lastStatusCode: 200

  // Rate Limiting (Wallhaven unauthenticated limit is 45 requests/minute)
  property double rateLimitedUntil: 0
  readonly property bool isRateLimited: rateLimitedUntil > Date.now()
  readonly property int rateLimitCooldownRemaining: Math.max(0, Math.ceil((rateLimitedUntil - Date.now()) / 1000))

  // Sliding window timestamps of recent requests (last 60s)
  property var requestTimestamps: []

  // Timeout settings
  property int searchTimeoutMs: 25000
  property int downloadTimeoutMs: 60000

  // Current active operations metadata
  property var currentSearchParams: null
  property var currentDownloadInfo: null

  // Signals
  signal searchSuccess(var wallpapers, var meta, var params)
  signal searchFailed(string error, int statusCode)
  signal downloadSuccess(string wallpaperId, string localPath)
  signal downloadFailed(string wallpaperId, string error)

  // Rate limit guard and sliding window registration
  function checkRateLimit() {
    var now = Date.now()
    if (root.isRateLimited) return false

    // Clean up timestamps older than 60 seconds
    var threshold = now - 60000
    var recent = []
    for (var i = 0; i < requestTimestamps.length; i++) {
      if (requestTimestamps[i] > threshold) {
        recent.push(requestTimestamps[i])
      }
    }
    requestTimestamps = recent

    // If approaching 45 requests/min limit (e.g. 42 requests in last 60s), throttle
    if (recent.length >= 42) {
      rateLimitedUntil = now + 15000
      return false
    }

    recent.push(now)
    requestTimestamps = recent
    return true
  }

  // Cancel any ongoing search
  function cancelSearch() {
    searchTimeoutTimer.stop()
    if (fetchProc.running) {
      fetchProc.running = false
    }
    searching = false
  }

  // Cancel any ongoing download
  function cancelDownload() {
    downloadTimeoutTimer.stop()
    if (downloadProc.running) {
      downloadProc.running = false
    }
    downloading = false
  }

  // Cancel all active operations
  function cancelAll() {
    cancelSearch()
    cancelDownload()
  }

  // Execute search against Wallhaven API
  function search(params) {
    if (!params) params = {}

    if (root.isRateLimited) {
      root.lastError = "Rate limited: cooldown " + root.rateLimitCooldownRemaining + "s remaining"
      root.lastStatusCode = 429
      root.searchFailed(root.lastError, 429)
      return
    }

    if (!checkRateLimit()) {
      root.lastError = "Approaching Wallhaven rate limit (45 req/min). Cooldown " + root.rateLimitCooldownRemaining + "s."
      root.lastStatusCode = 429
      root.searchFailed(root.lastError, 429)
      return
    }

    if (searching) {
      cancelSearch()
    }

    searching = true
    lastError = ""
    lastStatusCode = 0
    currentSearchParams = params

    searchTimeoutTimer.restart()

    var color = params.color || ""
    var keywords = params.keywords || ""
    var categories = params.categories || "100"
    var purity = params.purity || "100"
    var resolution = params.resolution || "1920x1080"
    var page = String(params.page || 1)

    fetchProc.stdoutText = ""
    fetchProc.stderrText = ""
    fetchProc.command = [
      "bash",
      pluginDir + "/scripts/fetch-wallpapers.sh",
      "--color", color,
      "--keywords", keywords,
      "--categories", categories,
      "--purity", purity,
      "--atleast", resolution,
      "--page", page
    ]
    fetchProc.running = true
  }

  // Process runner for API query
  Process {
    id: fetchProc
    running: false
    property string stdoutText: ""
    property string stderrText: ""

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: fetchProc.stdoutText = (text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: fetchProc.stderrText = (text || "").trim()
    }

    onExited: function(exitCode, exitStatus) {
      root.handleSearchExited(exitCode, fetchProc.stdoutText, fetchProc.stderrText)
    }
  }

  // Search completion handler
  function handleSearchExited(exitCode, stdoutText, stderrText) {
    searchTimeoutTimer.stop()
    searching = false

    if (exitCode !== 0) {
      lastStatusCode = (exitCode === 124) ? 408 : 500
      lastError = stderrText || ("Wallhaven search failed with exit code " + exitCode)
      searchFailed(lastError, lastStatusCode)
      return
    }

    if (!stdoutText || stdoutText.length === 0) {
      lastStatusCode = 500
      lastError = "Empty response from Wallhaven fetch script"
      searchFailed(lastError, 500)
      return
    }

    try {
      var json = JSON.parse(stdoutText)
      if (json.error) {
        if (/too many requests|429/i.test(json.error)) {
          root.rateLimitedUntil = Date.now() + 60000
          root.lastStatusCode = 429
        } else {
          root.lastStatusCode = 400
        }
        root.lastError = json.error
        root.searchFailed(root.lastError, root.lastStatusCode)
        return
      }

      var wallpapers = json.data || []
      var meta = json.meta || {}
      root.lastStatusCode = 200
      root.searchSuccess(wallpapers, meta, root.currentSearchParams)
    } catch (e) {
      root.lastStatusCode = 500
      root.lastError = "Failed to parse Wallhaven response: " + e.message
      root.searchFailed(root.lastError, 500)
    }
  }

  // Search Timeout Timer
  Timer {
    id: searchTimeoutTimer
    interval: root.searchTimeoutMs
    repeat: false
    onTriggered: {
      if (root.searching) {
        root.cancelSearch()
        root.lastStatusCode = 408
        root.lastError = "Wallhaven search timed out after " + Math.round(root.searchTimeoutMs / 1000) + "s"
        root.searchFailed(root.lastError, 408)
      }
    }
  }

  // Download wallpaper image to local cache
  function download(wallpaper, targetPath, targetResolution) {
    if (!wallpaper || !wallpaper.path) {
      downloadFailed((wallpaper && wallpaper.id) || "", "Invalid wallpaper data")
      return
    }

    if (downloading) {
      downloadFailed(wallpaper.id, "Another download is already in progress")
      return
    }

    downloading = true
    currentDownloadInfo = {
      wallpaper: wallpaper,
      targetPath: targetPath,
      targetResolution: targetResolution
    }

    downloadTimeoutTimer.restart()

    var cmd = [
      "bash",
      pluginDir + "/scripts/download-wallpaper.sh",
      "--url", wallpaper.path,
      "--id", wallpaper.id || ""
    ]
    if (targetPath) {
      cmd.push("--out", targetPath)
    }
    if (targetResolution) {
      cmd.push("--res", targetResolution)
    }

    downloadProc.stdoutText = ""
    downloadProc.stderrText = ""
    downloadProc.command = cmd
    downloadProc.running = true
  }

  // Process runner for image download and optional resize
  Process {
    id: downloadProc
    running: false
    property string stdoutText: ""
    property string stderrText: ""

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: downloadProc.stdoutText = (text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: downloadProc.stderrText = (text || "").trim()
    }

    onExited: function(exitCode, exitStatus) {
      root.handleDownloadExited(exitCode, downloadProc.stdoutText, downloadProc.stderrText)
    }
  }

  // Download completion handler
  function handleDownloadExited(exitCode, stdoutText, stderrText) {
    downloadTimeoutTimer.stop()
    downloading = false

    var wpId = (currentDownloadInfo && currentDownloadInfo.wallpaper) ? currentDownloadInfo.wallpaper.id : ""

    if (exitCode !== 0) {
      lastError = stderrText || ("Download failed with exit code " + exitCode)
      downloadFailed(wpId, lastError)
      return
    }

    var localPath = stdoutText
    if (!localPath && currentDownloadInfo && currentDownloadInfo.targetPath) {
      localPath = currentDownloadInfo.targetPath
    }

    downloadSuccess(wpId, localPath)
  }

  // Download Timeout Timer
  Timer {
    id: downloadTimeoutTimer
    interval: root.downloadTimeoutMs
    repeat: false
    onTriggered: {
      if (root.downloading) {
        var wpId = (root.currentDownloadInfo && root.currentDownloadInfo.wallpaper) ? root.currentDownloadInfo.wallpaper.id : ""
        root.cancelDownload()
        root.downloadFailed(wpId, "Download timed out after " + Math.round(root.downloadTimeoutMs / 1000) + "s")
      }
    }
  }
}
