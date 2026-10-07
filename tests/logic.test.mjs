import { test } from "node:test"
import assert from "node:assert/strict"
import { createRequire } from "node:module"
import { readFileSync, existsSync } from "node:fs"
import { spawnSync } from "node:child_process"

const require = createRequire(import.meta.url)
const L = require("../Logic.js")
const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "")
const dir = root + "/shaders"
const own = (id) => `${dir}/${id}.glsl`

test("parses getoption output", () => {
  assert.equal(L.parseShaderOption('{"option": "decoration:screen_shader", "str": "[[EMPTY]]", "set": false }'), "")
  assert.equal(L.parseShaderOption('{"str": "/x/y.glsl"}'), "/x/y.glsl")
  assert.equal(L.parseShaderOption("garbage"), "")
})

test("normalizes bad state", () => {
  assert.deepEqual(L.normalizeState("{nope"), { filter: "off", last: "deuteranopia", previous: "" })
  assert.deepEqual(L.normalizeState('{"filter":"evil","last":"tritanopia","previous":3}'), { filter: "off", last: "tritanopia", previous: "" })
  const s = { filter: "grayscale", last: "grayscale", previous: "/a.glsl" }
  assert.deepEqual(L.normalizeState(L.serialize(s)), s)
})

test("recognizes own shaders, also from another checkout", () => {
  assert.ok(L.isOwnShader(own("protanopia"), dir))
  assert.ok(L.isOwnShader("/home/u/.config/omarchy/plugins/nejcc.color-assist/shaders/grayscale.glsl", "/elsewhere"))
  assert.ok(!L.isOwnShader("/home/u/.config/omarchy/plugins/archisman-panigrahi.grayscale/shaders/grayscale.glsl", dir))
  assert.ok(!L.isOwnShader("", dir))
})

test("enable remembers the foreign shader, off restores it", () => {
  const off = L.normalizeState("")
  let r = L.select(off, "tritanopia", "/theirs.glsl", dir)
  assert.equal(r.shader, own("tritanopia"))
  assert.deepEqual(r.state, { filter: "tritanopia", last: "tritanopia", previous: "/theirs.glsl" })

  // switching filters keeps the original previous
  r = L.select(r.state, "grayscale", own("tritanopia"), dir)
  assert.equal(r.shader, own("grayscale"))
  assert.equal(r.state.previous, "/theirs.glsl")

  r = L.select(r.state, "off", own("grayscale"), dir)
  assert.equal(r.shader, "/theirs.glsl")
  assert.deepEqual(r.state, { filter: "off", last: "grayscale", previous: "/theirs.glsl" })
})

test("off restores an empty shader", () => {
  const r = L.select({ filter: "grayscale", last: "grayscale", previous: "" }, "off", own("grayscale"), dir)
  assert.equal(r.shader, "")
})

test("off leaves another plugin's shader alone", () => {
  const r = L.select({ filter: "grayscale", last: "grayscale", previous: "" }, "off", "/theirs.glsl", dir)
  assert.equal(r.shader, null)
  assert.equal(r.state.filter, "off")
})

test("restart with our shader still on keeps the saved previous", () => {
  const saved = L.normalizeState('{"filter":"protanopia","last":"protanopia","previous":"/p.glsl"}')
  const r = L.select(saved, saved.filter, own("protanopia"), dir)
  assert.equal(r.shader, own("protanopia"))
  assert.equal(r.state.previous, "/p.glsl")
})

test("unknown filter is ignored", () => {
  const s = L.normalizeState("")
  assert.deepEqual(L.select(s, "rm -rf", "", dir), { state: s, shader: null })
})

test("toggle goes to last filter and back", () => {
  assert.equal(L.toggleTarget({ filter: "off", last: "tritanopia" }), "tritanopia")
  assert.equal(L.toggleTarget({ filter: "tritanopia", last: "tritanopia" }), "off")
})

test("lua command escapes the path", () => {
  assert.equal(L.luaSetShader('/a "b"\\c'), 'hl.config({ decoration = { screen_shader = "/a \\"b\\"\\\\c" } })')
  assert.equal(L.luaSetShader(""), 'hl.config({ decoration = { screen_shader = "" } })')
})

test("every filter has a valid shader", (t) => {
  const glslang = spawnSync("glslangValidator", ["--version"]).status === 0
  if (!glslang) t.diagnostic("glslangValidator not installed, checking source only")
  for (const f of L.FILTERS) {
    const path = own(f.id)
    assert.ok(existsSync(path), path)
    const src = readFileSync(path, "utf8")
    assert.match(src, /^#version 300 es\n/, `${f.id}: #version must be the first line`)
    assert.match(src, /void main\(\)/, `${f.id}: entry point`)
    assert.match(src, /uniform sampler2D tex;/, `${f.id}: tex uniform`)
    assert.match(src, /in vec2 v_texcoord;/, `${f.id}: v_texcoord`)
    if (glslang) {
      const r = spawnSync("glslangValidator", ["-S", "frag", path], { encoding: "utf8" })
      assert.equal(r.status, 0, `${f.id}: ${r.stdout}${r.stderr}`)
    }
  }
})
