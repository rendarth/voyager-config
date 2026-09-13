function integer(value) {
  var number = Number(value)
  if (!isFinite(number) || Math.floor(number) !== number) return null
  return number
}

function workspaceNumber(value, fallback) {
  var number = integer(value)
  if (number === null || number < 1 || number > 10) return fallback
  return number
}

function parsedBoolean(value) {
  if (value === true || value === false) return { valid: true, value: value }
  var text = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
  if (text === "true" || text === "1" || text === "yes" || text === "on")
    return { valid: true, value: true }
  if (text === "false" || text === "0" || text === "no" || text === "off")
    return { valid: true, value: false }
  return { valid: false, value: false }
}

function booleanSetting(value, fallback) {
  if (value === undefined || value === null || value === "") return fallback
  var parsed = parsedBoolean(value)
  return parsed.valid ? parsed.value : fallback
}

function normalizeAddress(value) {
  var address = String(value || "").trim()
  if (!/^(0x)?[0-9a-fA-F]+$/.test(address)) return ""
  return address.indexOf("0x") === 0 ? address.toLowerCase() : "0x" + address.toLowerCase()
}

function isTrueFullscreenMode(value) {
  if (value === true) return true
  var mode = Number(value)
  return mode === 2 || mode === 3
}

function normalizedStringList(value) {
  var source = Array.isArray(value) ? value : []
  var result = []
  for (var i = 0; i < source.length; i++) {
    var item = String(source[i] || "").trim()
    if (item && result.indexOf(item) === -1) result.push(item)
  }
  return result
}

function commaSeparatedList(value) {
  var text = String(value || "")
  if (!text.trim()) return []
  return normalizedStringList(text.split(","))
}

function mergedStringLists(first, second) {
  return normalizedStringList(normalizedStringList(first).concat(normalizedStringList(second)))
}

function isExcluded(candidates, exclusions) {
  var wanted = normalizedStringList(exclusions).map(function(value) { return value.toLowerCase() })
  var actual = normalizedStringList(candidates)
  for (var i = 0; i < actual.length; i++)
    if (wanted.indexOf(actual[i].toLowerCase()) !== -1) return true
  return false
}

function isSpecialWorkspace(name) {
  return String(name || "").indexOf("special:") === 0
}

function luaString(value) {
  return "\"" + String(value)
    .replace(/\\/g, "\\\\")
    .replace(/\"/g, "\\\"")
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t") + "\""
}
