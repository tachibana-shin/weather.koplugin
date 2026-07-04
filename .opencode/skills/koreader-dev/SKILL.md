---
name: koreader-dev
description: KOReader plugin development — widget toolkit quirks, Lua 5.1 constraints, SVG rendering rules, Trapper async patterns, and HTTP API conventions
license: MIT
compatibility: opencode
metadata:
  audience: plugin-developers
---

# KOReader Plugin Development Skill

## Lua 5.1 Constraints
- No `continue` — use `goto` or restructure with `if`/`else`
- No trailing comma in function call arguments: `f(1, 2,)` → syntax error
- No `+=`, `-=` etc — use `x = x + 1`
- `pcall(require, ...)` for optional modules (`socket.http`, `json`)

## Widget Toolkit Quirks

### FrameContainer — `getSize()`
- **Ignores `width`/`height`/`dimen`** values set via constructor
- Always calculates from `self[1]:getSize()` + padding + borders
- Source: `frontend/ui/widget/container/framecontainer.lua:54`
- **Fix for fixed size**: use `CenterContainer{ dimen = Geom:new{ w = ..., h = ... } }` instead

### WidgetContainer — `getSize()`
- `CenterContainer`, `LeftContainer`, `RightContainer`, `InputContainer` extend `WidgetContainer`
- Checks `self.dimen` **first** before delegating to child
- Use for fixed-size containers when FrameContainer fails
- Source: `frontend/ui/widget/container/widgetcontainer.lua:22`

### ScrollableContainer — scrollbar math
- When vertical scrollbar appears, viewport width shrinks by `3 * scroll_bar_width`
- Inner content width **must** be `sw - sbw` to prevent horizontal scrollbar
- `ScrollableContainer:getScrollbarWidth()` returns `3 * scroll_bar_width`
- Source: `frontend/ui/widget/container/scrollablecontainer.lua:132-144, 85`

### FitWidthContainer pattern
- Custom `InputContainer:extend{}` that reports fixed `fw` width but delegates height to child
- Use to wrap content inside ScrollableContainer so horizontal scrollbar doesn't appear
- Implementation:
```lua
local FitWidthContainer = InputContainer:extend{
  fw = 0,
}
function FitWidthContainer:getSize()
  return Geom:new{ w = self.fw, h = self[1]:getSize().h }
end
```

### Alignment containers
- `LeftContainer`: left-aligns child within `dimen`, vertically centers
- `RightContainer`: right-aligns child within `dimen`, vertically centers
- `CenterContainer`: centers child in `dimen`, no background
- All inherit from WidgetContainer — respect `dimen`, not child size

### OverlapGroup
- Layers children on top of each other
- Size = size of first child
- Useful for overlaying text on images or combining elements

## SVG Rendering Rules
- KOReader's SVG renderer (`MuPDF`/`draw`) is limited
- `ImageWidget` with SVGs needs: `alpha = true, is_icon = true`
- **Unsupported elements** (will fail to render):
  - `<text>` — no text rendering in SVGs
  - `<defs>` — no definitions
  - `<linearGradient>` / `<radialGradient>` — no gradients
  - `<stop>` — part of gradients
- Use raw paths, simple shapes (`<rect>`, `<circle>`, `<path>`, `<polyline>`)
- Stroke-dasharray/dashoffset are supported (used for gauge SVGs)
- SVGs can be overwritten at runtime by writing new SVG content to the file on disk

## Trapper — Asynchronous Patterns
- `Trapper:wrap(function() end)` for coroutine-based non-blocking flows
- `Trapper:info()` shows a dismissable progress message
  - Returns `false` if user dismissed it
  - Yields ~0.1s for UI refresh
- `Trapper:clear()` closes the current InfoMessage
- **Important**: Button callbacks from `ButtonDialog` / `InputDialog` run **outside** the Trapper coroutine
  - Don't call `Trapper:info()` inside button callbacks
  - Do call `Trapper:clear()` before showing a `ButtonDialog` to dismiss the info message first

## HTTP API Conventions
- `http.request(url)` — blocking, string form
- `http.request{ url = ..., timeout = 15 }` — table form with per-request timeout
- `http.TIMEOUT = N` sets global timeout (affects all subsequent requests)
- Always guard with `pcall()`:
  ```lua
  local ok, http = pcall(require, "socket.http")
  if not ok then return end
  ```
- Open-Meteo:
  - Weather: `https://api.open-meteo.com/v1/forecast`
  - Geocoding: `https://geocoding-api.open-meteo.com/v1/search?name=...&count=N&language=en&format=json`
- Auto-detect location: `http://ip-api.com/json/`
- Always URL-encode query parameters (libraries usually have `urlencode` or similar)

## Dirty Rectangle Propagation
- `UIManager:setDirty(widget, "method", "region")` needs `show_parent` set on the widget for scrollable views
- Without `show_parent`, dirty regions may not propagate through scrollable containers

## Plugin Structure
- Symlink repo → `~/.config/koreader/plugins/<name>.koplugin/` for live edits
- Entrypoint: `main.lua` — `WidgetContainer:extend`, menu registration, Dispatcher
- UI Widget: separate file (e.g., `weatherview.lua`) — `FocusManager` + all rendering
- API client: separate file (e.g., `weatherapi.lua`) — HTTP calls + response parsing
- Config: auto-persisting key-value store writing `.lua` config file
- i18n: translations via `gettext()` with fallback

## Render Flow
1. `FocusManager` wraps the full-screen widget
2. One main `CenterContainer` with `dimen = Screen:getSize()`
3. `ScrollableContainer` inside for vertical scrolling
4. `FitWidthContainer` wrapping the content to prevent horizontal scroll
5. Build UI blocks/modules and add to a `FrameContainer` with `VERTICAL` direction
6. Use `Screen:scaleBySize()` for all dimensions — never hardcode pixels
