import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  // Theme colors loaded from colors.toml
  property var themeColors: ({})
  property bool loaded: false

  // Path to the active theme's colors.toml
  readonly property string home: Quickshell.env("HOME")
  readonly property string currentThemeColorsPath: home + "/.local/state/omarchy/current/theme/colors.toml"

  // Wallhaven API 29-color palette
  readonly property var wallhavenPalette: [
    "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399",
    "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900",
    "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300",
    "000000", "999999", "cccccc", "ffffff", "424153"
  ]

  // Available color categories for UI picker
  readonly property var colorCategories: [
    {
      name: "Accents",
      keys: ["accent", "selection", "muted"]
    },
    {
      name: "Backgrounds",
      keys: ["background", "dark_background", "darker_background", "lighter_background"]
    },
    {
      name: "Foregrounds",
      keys: ["foreground", "dark_foreground", "light_foreground", "bright_foreground"]
    },
    {
      name: "Standard Colors",
      keys: ["red", "yellow", "orange", "green", "cyan", "blue", "magenta", "brown"]
    },
    {
      name: "Bright Colors",
      keys: ["bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta"]
    }
  ]

  // Clean hex (strip leading # and whitespace, lowercase)
  function stripHash(hex) {
    if (!hex) return ""
    return String(hex).replace(/^\s+|\s+$/g, "").replace(/^#/, "").toLowerCase()
  }

  // Ensure leading #
  function ensureHash(hex) {
    if (!hex) return "#000000"
    var clean = stripHash(hex)
    return "#" + clean
  }

  // Validate hex string (3 or 6 hex digits)
  function isValidHex(hex) {
    var clean = stripHash(hex)
    return /^[0-9a-f]{3}$|^[0-9a-f]{6}$/i.test(clean)
  }

  // Convert hex to RGB object { r, g, b } (0..255)
  function hexToRgb(hex) {
    var clean = stripHash(hex)
    if (clean.length === 3) {
      clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2]
    }
    if (clean.length !== 6) {
      return { r: 0, g: 0, b: 0 }
    }
    var num = parseInt(clean, 16)
    if (isNaN(num)) return { r: 0, g: 0, b: 0 }
    return {
      r: (num >> 16) & 255,
      g: (num >> 8) & 255,
      b: num & 255
    }
  }

  // Convert RGB (0..255) to 6-char hex without #
  function rgbToHex(r, g, b) {
    var rc = Math.max(0, Math.min(255, Math.round(r)))
    var gc = Math.max(0, Math.min(255, Math.round(g)))
    var bc = Math.max(0, Math.min(255, Math.round(b)))
    var hex = ((rc << 16) | (gc << 8) | bc).toString(16)
    while (hex.length < 6) hex = "0" + hex
    return hex
  }

  // RGB (0..255) to HSL ({ h: 0..360, s: 0..1, l: 0..1 })
  function rgbToHsl(r, g, b) {
    var rn = r / 255.0
    var gn = g / 255.0
    var bn = b / 255.0
    var max = Math.max(rn, gn, bn)
    var min = Math.min(rn, gn, bn)
    var d = max - min
    var h = 0
    var s = 0
    var l = (max + min) / 2.0

    if (d > 0.00001) {
      s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)
      if (max === rn) {
        h = ((gn - bn) / d) + (gn < bn ? 6.0 : 0.0)
      } else if (max === gn) {
        h = ((bn - rn) / d) + 2.0
      } else {
        h = ((rn - gn) / d) + 4.0
      }
      h = h * 60.0
    }
    return { h: h, s: s, l: l }
  }

  // HSL ({ h: 0..360, s: 0..1, l: 0..1 }) to RGB ({ r, g, b })
  function hslToRgb(h, s, l) {
    var r, g, b
    if (s < 0.00001) {
      r = g = b = Math.round(l * 255.0)
      return { r: r, g: g, b: b }
    }

    function hue2rgb(p, q, t) {
      if (t < 0) t += 1
      if (t > 1) t -= 1
      if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t
      if (t < 1.0 / 2.0) return q
      if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0
      return p
    }

    var q = l < 0.5 ? l * (1.0 + s) : l + s - l * s
    var p = 2.0 * l - q
    var hNorm = h / 360.0

    r = Math.round(hue2rgb(p, q, hNorm + 1.0 / 3.0) * 255.0)
    g = Math.round(hue2rgb(p, q, hNorm) * 255.0)
    b = Math.round(hue2rgb(p, q, hNorm - 1.0 / 3.0) * 255.0)

    return { r: r, g: g, b: b }
  }

  // Complementary color calculation: rotate hue by 180 degrees
  function getComplementaryHex(hex) {
    var rgb = hexToRgb(hex)
    var hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)
    var compH = (hsl.h + 180.0) % 360.0
    var compRgb = hslToRgb(compH, hsl.s, hsl.l)
    return rgbToHex(compRgb.r, compRgb.g, compRgb.b)
  }

  // Snap hex to closest Wallhaven supported palette color
  function snapToWallhavenColor(hex) {
    var clean = stripHash(hex)
    if (!clean) return "0066cc"
    for (var i = 0; i < wallhavenPalette.length; i++) {
      if (wallhavenPalette[i] === clean) return clean
    }
    var target = hexToRgb(clean)
    var best = wallhavenPalette[0]
    var minDist = 99999999
    for (var j = 0; j < wallhavenPalette.length; j++) {
      var candidate = hexToRgb(wallhavenPalette[j])
      var dr = target.r - candidate.r
      var dg = target.g - candidate.g
      var db = target.b - candidate.b
      var dist = dr * dr + dg * dg + db * db
      if (dist < minDist) {
        minDist = dist
        best = wallhavenPalette[j]
      }
    }
    return best
  }

  // Convert sRGB to CIE L*a*b* (D65 standard illuminant)
  function rgbToLab(r, g, b) {
    function pivotRgb(c) {
      var cn = c / 255.0
      return cn <= 0.04045 ? (cn / 12.92) : Math.pow((cn + 0.055) / 1.055, 2.4)
    }

    var rLin = pivotRgb(r)
    var gLin = pivotRgb(g)
    var bLin = pivotRgb(b)

    var x = (rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375) / 0.95047
    var y = (rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750) / 1.00000
    var z = (rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041) / 1.08883

    function pivotXyz(v) {
      return v > 0.008856 ? Math.cbrt(v) : (7.787 * v + 16.0 / 116.0)
    }

    var fx = pivotXyz(x)
    var fy = pivotXyz(y)
    var fz = pivotXyz(z)

    var L = Math.max(0.0, 116.0 * fy - 16.0)
    var a = 500.0 * (fx - fy)
    var bVal = 200.0 * (fy - fz)

    return { L: L, a: a, b: bVal }
  }

  // Hex to CIE L*a*b*
  function hexToLab(hex) {
    var rgb = hexToRgb(hex)
    return rgbToLab(rgb.r, rgb.g, rgb.b)
  }

  // CIE76 Delta-E color distance between two hex colors
  function deltaE(hex1, hex2) {
    var lab1 = hexToLab(hex1)
    var lab2 = hexToLab(hex2)
    var dL = lab1.L - lab2.L
    var da = lab1.a - lab2.a
    var db = lab1.b - lab2.b
    return Math.sqrt(dL * dL + da * da + db * db)
  }

  // Euclidean RGB distance between two hex colors
  function rgbDistance(hex1, hex2) {
    var rgb1 = hexToRgb(hex1)
    var rgb2 = hexToRgb(hex2)
    var dr = rgb1.r - rgb2.r
    var dg = rgb1.g - rgb2.g
    var db = rgb1.b - rgb2.b
    return Math.sqrt(dr * dr + dg * dg + db * db)
  }

  // Score a single wallpaper against selected theme colors.
  // Formula:
  // For each theme color, find minimum Delta-E to any dominant wallpaper color.
  // Lower score = better match.
  // Multi-color weighting: rewarded for matching multiple theme colors (< 28.0 Delta-E).
  function scoreWallpaper(wallpaperColors, themeColors) {
    if (!wallpaperColors || wallpaperColors.length === 0 || !themeColors || themeColors.length === 0) {
      return 9999.0
    }

    var totalDist = 0.0
    var matchedCount = 0
    var closeThreshold = 28.0 // Delta-E threshold for aesthetically harmonious match

    for (var i = 0; i < themeColors.length; i++) {
      var tColor = themeColors[i]
      var minDist = 9999.0

      for (var j = 0; j < wallpaperColors.length; j++) {
        var dist = deltaE(tColor, wallpaperColors[j])
        if (dist < minDist) {
          minDist = dist
        }
      }

      totalDist += minDist
      if (minDist <= closeThreshold) {
        matchedCount += 1
      }
    }

    // Weighting: Reward matching multiple selected colors
    var matchRatio = matchedCount / Math.max(1, themeColors.length)
    var bonus = 1.0 + (matchRatio * 0.4) // up to 40% discount for matching all selected colors
    var score = totalDist / bonus
    return Math.round(score * 100) / 100.0
  }

  // Sort wallpaper array by match score ascending (best first)
  function sortWallpapers(wallpapers, themeColors) {
    if (!wallpapers || wallpapers.length === 0) return []
    var items = []
    for (var i = 0; i < wallpapers.length; i++) {
      var wp = wallpapers[i]
      var copy = Object.assign({}, wp)
      copy.score = scoreWallpaper(wp.colors || [], themeColors)
      items.push(copy)
    }
    items.sort(function(a, b) {
      return a.score - b.score
    })
    return items
  }

  // Parse colors.toml text into key -> hex map
  function parseColorsToml(rawText) {
    var result = {}
    if (!rawText) return result
    var lines = String(rawText).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].replace(/^\s+|\s+$/g, "")
      if (!line || line.charAt(0) === "#") continue
      var match = line.match(/^([a-zA-Z0-9_-]+)\s*=\s*["']([^"']+)["']/)
      if (match) {
        result[match[1]] = match[2]
      }
    }
    return result
  }

  // Resolve a color key to a hex string
  function getColor(key, fallback) {
    if (!key) return fallback || "#5a7a7a"
    if (key.charAt(0) === "#") return key
    if (themeColors && themeColors[key]) return themeColors[key]

    // Fall back to Color singleton properties
    if (key === "accent" && Color.accent) return Color.accent.toString()
    if (key === "background" && Color.background) return Color.background.toString()
    if (key === "foreground" && Color.foreground) return Color.foreground.toString()
    if (key === "urgent" && Color.urgent) return Color.urgent.toString()
    if (key === "muted" && Color.muted) return Color.muted.toString()

    return fallback || "#5a7a7a"
  }

  // Resolve list of color keys to hex list
  function resolveThemeColors(keys) {
    if (!keys || keys.length === 0) {
      return [getColor("accent"), getColor("background")]
    }
    var resolved = []
    for (var i = 0; i < keys.length; i++) {
      var col = getColor(keys[i])
      if (col && resolved.indexOf(col) === -1) {
        resolved.push(col)
      }
    }
    return resolved.length > 0 ? resolved : [getColor("accent")]
  }

  // Select the Wallhaven query color (6-digit hex without #) based on mode
  function getSearchColor(resolvedThemeColors, colorMode) {
    var primary = (resolvedThemeColors && resolvedThemeColors.length > 0)
      ? resolvedThemeColors[0]
      : getColor("accent")
    var cleanHex = stripHash(primary)

    var mode = (colorMode || "matching").toLowerCase()

    if (mode === "complementary") {
      return getComplementaryHex(cleanHex)
    } else if (mode === "surprise" || mode === "surprise me") {
      var isComp = Math.random() < 0.5
      return isComp ? getComplementaryHex(cleanHex) : cleanHex
    }

    // Default "matching"
    return cleanHex
  }

  // Load colors file
  FileView {
    id: colorsFileView
    path: root.currentThemeColorsPath
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.themeColors = root.parseColorsToml(text())
      root.loaded = true
    }
    onLoadFailed: {
      root.themeColors = root.parseColorsToml("")
      root.loaded = true
    }
  }

  function reloadTheme() {
    colorsFileView.reload()
  }

  Component.onCompleted: {
    reloadTheme()
  }
}
