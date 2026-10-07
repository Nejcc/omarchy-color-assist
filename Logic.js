// Filter and state logic for Color Assist. Plain JS so node can test it
// (tests/logic.test.mjs) and QML can import it.

var FILTERS = [
  { id: "deuteranopia", label: "Deuteranopia", hint: "Red-green, weak green" },
  { id: "protanopia", label: "Protanopia", hint: "Red-green, weak red" },
  { id: "tritanopia", label: "Tritanopia", hint: "Blue-yellow" },
  { id: "grayscale", label: "Grayscale", hint: "No color" },
  { id: "high-contrast", label: "High contrast", hint: "Stronger contrast and saturation" }
]

var OFF = "off"

function isFilter(id) {
  for (var i = 0; i < FILTERS.length; i++) if (FILTERS[i].id === id) return true
  return false
}

function labelFor(id) {
  for (var i = 0; i < FILTERS.length; i++) if (FILTERS[i].id === id) return FILTERS[i].label
  return "Off"
}

function shaderPath(dir, id) {
  return dir + "/" + id + ".glsl"
}

// Ours if it lives in this plugin's shaders/ dir, or in any older checkout of
// it (the install path changes when the plugin id dir is renamed or cloned).
function isOwnShader(path, dir) {
  path = String(path || "")
  if (path === "") return false
  if (dir && path.indexOf(dir + "/") === 0) return true
  var m = path.match(/color-assist[^/]*\/shaders\/([^/]+)\.glsl$/)
  return !!m && isFilter(m[1])
}

// `hyprctl -j getoption decoration:screen_shader` → path, "" when unset.
function parseShaderOption(text) {
  try {
    var s = String(JSON.parse(text).str || "")
    return s === "[[EMPTY]]" ? "" : s
  } catch (e) {
    return ""
  }
}

function normalizeState(raw) {
  var s = {}
  try { s = JSON.parse(raw || "{}") || {} } catch (e) { s = {} }
  return {
    filter: isFilter(s.filter) ? s.filter : OFF,
    last: isFilter(s.last) ? s.last : FILTERS[0].id,
    previous: typeof s.previous === "string" ? s.previous : ""
  }
}

function serialize(state) {
  return JSON.stringify({ filter: state.filter, last: state.last, previous: state.previous }) + "\n"
}

function toggleTarget(state) {
  return state.filter === OFF ? state.last : OFF
}

// Decide what to do when `id` is chosen while Hyprland currently shows
// `current`. Returns the next state and the shader to set, or null to leave
// screen_shader alone.
function select(state, id, current, dir) {
  if (id !== OFF && !isFilter(id)) return { state: state, shader: null }
  var own = isOwnShader(current, dir)
  // Whatever non-Color-Assist shader is on screen is what Off goes back to.
  var previous = own ? state.previous : current
  var next = { filter: id, last: id === OFF ? state.last : id, previous: previous }
  if (id === OFF) {
    // Someone else replaced our shader already: theirs stays.
    return { state: next, shader: own ? previous : null }
  }
  return { state: next, shader: shaderPath(dir, id) }
}

function luaString(s) {
  return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\""
}

// Hyprland 0.56+ parses options through the Lua config, so runtime changes
// go through `hyprctl eval` rather than `hyprctl keyword`.
function luaSetShader(path) {
  return "hl.config({ decoration = { screen_shader = " + luaString(path) + " } })"
}

if (typeof module !== "undefined") {
  module.exports = {
    FILTERS: FILTERS,
    OFF: OFF,
    isFilter: isFilter,
    labelFor: labelFor,
    shaderPath: shaderPath,
    isOwnShader: isOwnShader,
    parseShaderOption: parseShaderOption,
    normalizeState: normalizeState,
    serialize: serialize,
    toggleTarget: toggleTarget,
    select: select,
    luaSetShader: luaSetShader
  }
}
