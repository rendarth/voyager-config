import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../FullscreenWorkspace.js", import.meta.url), "utf8")
const logic = { console }
vm.createContext(logic)
vm.runInContext(source, logic)

assert.equal(logic.workspaceNumber(9, 4), 9)
assert.equal(logic.workspaceNumber("10", 4), 10)
assert.equal(logic.workspaceNumber(0, 4), 4)
assert.equal(logic.workspaceNumber(11, 4), 4)
assert.equal(logic.workspaceNumber(2.5, 4), 4)

assert.equal(logic.parsedBoolean("yes").valid, true)
assert.equal(logic.parsedBoolean("yes").value, true)
assert.equal(logic.parsedBoolean("off").valid, true)
assert.equal(logic.parsedBoolean("off").value, false)
assert.equal(logic.parsedBoolean("sometimes").valid, false)
assert.equal(logic.booleanSetting(undefined, true), true)
assert.equal(logic.booleanSetting(false, true), false)

assert.equal(logic.normalizeAddress("abc123"), "0xabc123")
assert.equal(logic.normalizeAddress("0xABC123"), "0xabc123")
assert.equal(logic.normalizeAddress("not-an-address"), "")

assert.equal(logic.isTrueFullscreenMode(0), false)
assert.equal(logic.isTrueFullscreenMode(1), false)
assert.equal(logic.isTrueFullscreenMode(2), true)
assert.equal(logic.isTrueFullscreenMode(3), true)
assert.equal(logic.isTrueFullscreenMode(true), true)

assert.deepEqual(
  Array.from(logic.commaSeparatedList("firefox, gamescope,firefox")),
  ["firefox", "gamescope"]
)
assert.equal(logic.isExcluded(["Gamescope"], ["gamescope"]), true)
assert.equal(logic.isExcluded(["firefox"], ["gamescope"]), false)
assert.equal(logic.isSpecialWorkspace("special:scratchpad"), true)
assert.equal(logic.isSpecialWorkspace("9"), false)

assert.equal(logic.luaString("a\\b\"c\n"), "\"a\\\\b\\\"c\\n\"")

console.log("logic tests passed")
