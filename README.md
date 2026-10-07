# Color Assist for Omarchy

Screen-wide color filters for color vision deficiency, plus grayscale and high
contrast. One click in the bar, applied by Hyprland itself, so every window,
the bar and fullscreen video all get it.

## Why

The plugin catalog had nothing for colorblind users, and accessibility on the
Linux desktop is thin in general. Red-green error states, diff colors, graphs
and map legends are hard to read with deuteranopia or protanopia. Hyprland can
run a fragment shader over the whole screen, so the fix is a handful of small
shaders and a toggle.

## Filters

| Filter | For |
|--------|-----|
| Deuteranopia | Red-green, weak or missing green cones (most common) |
| Protanopia | Red-green, weak or missing red cones |
| Tritanopia | Blue-yellow |
| Grayscale | No color at all, BT.709 luma |
| High contrast | Contrast stretch plus a saturation boost |

The three colorblind filters *daltonize*: they simulate what the eye loses,
then move that lost difference into channels it can still see. They do not
make the screen look "normal" to you; they make colors that used to look the
same look different. Sources are cited at the top of each shader:

- Deuteranopia and protanopia: Fidaner, Lin and Ozguven, *Analysis of Color
  Blindness* (2005), on the LMS model of Viénot, Brettel and Mollon (1999).
- Tritanopia: simulation from Machado, Oliveira and Fernandes (IEEE TVCG 2009),
  since the commonly copied Fidaner tritan row is badly off (pure red turns
  into a blue of −3). The error goes into red and green.

## Install

```bash
omarchy plugin add https://github.com/Nejcc/omarchy-color-assist.git
```

Then add the **Color Assist** widget to the bar.

## Usage

- **Left click** the eye icon: panel with Off and every filter. Arrows or
  `j`/`k` to move, Enter to pick, Esc to close.
- **Middle or right click**: toggle the last used filter on and off.
- The tooltip shows which filter is on.
- CLI:

  ```bash
  omarchy-shell color-assist status
  omarchy-shell color-assist set deuteranopia   # protanopia, tritanopia, grayscale, high-contrast
  omarchy-shell color-assist toggle
  omarchy-shell color-assist off
  ```

Bind one to a key in `~/.config/hypr/bindings.lua` if you want it on a key.

The choice is saved in `$XDG_STATE_HOME/omarchy-color-assist/state.json`
(default `~/.local/state/…`) and put back when the shell starts.

## How it works

A headless service owns the state, so two bars on two monitors never fight.
Picking a filter reads the current `decoration:screen_shader` with
`hyprctl getoption`, remembers it if it is not one of ours, and sets ours with:

```bash
hyprctl eval 'hl.config({ decoration = { screen_shader = "…/shaders/deuteranopia.glsl" } })'
```

Hyprland 0.56 reads options through the Lua config, so `hyprctl eval` is the
runtime path, not `hyprctl keyword`. **Off** puts back whatever shader was
there before, or none. After a Hyprland config reload the filter is set again
on top. Disabling or removing the plugin restores the previous shader too.

The shaders are plain GLSL ES 3.00 (`#version 300 es`, `tex`, `v_texcoord`),
the format Hyprland's screen shaders use.

## Runtime deps

Hyprland 0.56 or newer (Lua config, `hyprctl eval`). Nothing else.

## Limits

- **One screen shader at a time.** Hyprland has a single
  `decoration:screen_shader`, so this cannot stack with other shader plugins
  (Toggle Grayscale, Paper Mode) or a shader in your own config. Whoever sets
  it last wins. Color Assist remembers what was there before it and restores
  it on Off; if another plugin replaced our shader in the meantime, Off leaves
  theirs alone.
- **Night light is fine.** Omarchy's night light uses hyprsunset, which sets a
  color matrix on the output, not `screen_shader`. Both work together; the
  filter runs first and the warm tint goes on top.
- A screen shader costs a full-screen pass per frame and may stop direct
  scanout for fullscreen games. Turn it off for those.
- No magnifier yet; Hyprland's `cursor:zoom_factor` already covers that.

## Tests

```bash
node --test tests/*.test.mjs
```

Covers the state logic (what Off restores, restart, foreign shaders, Lua
escaping) and checks every shader exists with the right entry point. If
`glslangValidator` is installed it also compiles each one.

## License

MIT
