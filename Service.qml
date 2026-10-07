import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Logic.js" as Logic

// Owns the active filter: one instance per shell, so several bars never fight
// over screen_shader. The bar widget only calls select()/toggle().
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null

  readonly property string shaderDir: decodeURIComponent(String(Qt.resolvedUrl("shaders")).replace(/^file:\/\//, ""))
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy-color-assist"

  property var saved: Logic.normalizeState("")
  property bool stateLoaded: false
  readonly property string filter: saved.filter
  readonly property string lastFilter: saved.last
  readonly property bool active: filter !== Logic.OFF
  readonly property string label: Logic.labelFor(filter)

  // Requests are serialized: probe the live shader, decide, apply. The newest
  // request wins if several arrive while one is in flight.
  property string pending: ""
  property bool busy: false
  property var rollback: null

  function select(id) {
    if (id !== Logic.OFF && !Logic.isFilter(id)) return false
    pending = id
    pump()
    return true
  }

  // ponytail: toggles from the committed state, so two clicks inside one
  // probe+apply round trip (~10 ms) both aim at the same target.
  function toggle() {
    select(Logic.toggleTarget(saved))
  }

  function pump() {
    if (busy || pending === "") return
    busy = true
    probe.running = true
  }

  function decide(current) {
    var id = pending
    pending = ""
    var result = Logic.select(saved, id, current, shaderDir)
    rollback = saved
    saved = result.state
    saveTimer.restart()
    if (result.shader === null) {
      busy = false
      pump()
      return
    }
    apply.command = ["hyprctl", "eval", Logic.luaSetShader(result.shader)]
    apply.running = true
  }

  Process {
    id: probe
    command: ["hyprctl", "-j", "getoption", "decoration:screen_shader"]
    stdout: StdioCollector {
      id: probeOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (code !== 0) {
        console.warn("color-assist: hyprctl getoption failed (" + code + ")")
        root.busy = false
        root.pending = ""
        return
      }
      root.decide(Logic.parseShaderOption(probeOut.text))
    }
  }

  Process {
    id: apply
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    stdout: StdioCollector { id: applyOut; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) {
        console.warn("color-assist: hyprctl eval failed (" + code + "): " + applyOut.text + applyErr.text)
        root.saved = root.rollback
        saveTimer.restart()
      }
      root.busy = false
      root.pump()
    }
  }

  // A Hyprland config reload resets screen_shader to whatever the config
  // says; put the filter back on top of it.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded" && root.active) root.select(root.filter)
    }
  }

  Process {
    id: mkdir
    command: ["mkdir", "-p", root.stateDir]
  }

  Timer {
    id: saveTimer
    interval: 200
    onTriggered: if (root.stateLoaded) stateFile.setText(Logic.serialize(root.saved))
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.load("")
  }

  function load(raw) {
    if (stateLoaded) return
    saved = Logic.normalizeState(raw)
    stateLoaded = true
    if (active) select(filter)
  }

  Component.onCompleted: mkdir.running = true

  // Plugin disabled or removed: give the screen back. A shell restart runs
  // this too, and the next start puts the saved filter back.
  Component.onDestruction: {
    if (active) Quickshell.execDetached(["hyprctl", "eval", Logic.luaSetShader(saved.previous)])
  }

  IpcHandler {
    target: "color-assist"

    function status(): string {
      return JSON.stringify({ filter: root.filter, last: root.lastFilter })
    }

    function set(id: string): string {
      return root.select(id) ? id : "unknown filter: " + id
    }

    function off(): string {
      root.select(Logic.OFF)
      return Logic.OFF
    }

    function toggle(): string {
      var next = Logic.toggleTarget(root.saved)
      root.select(next)
      return next
    }
  }
}
