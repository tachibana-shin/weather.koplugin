# Weather.koplugin — AGENTS.md

## Project overview
KOReader plugin that displays a full-screen weather UI (Open-Meteo API). Self-contained in one directory; no build step, no tests, no CI.

## Key structure
- `main.lua` — Plugin entrypoint (`WidgetContainer:extend`), menu registration, dispatcher
- `weather_view.lua` — Full-screen `FocusManager` widget, all UI layout + rendering
- `weather_api.lua` — Open-Meteo API client, WMO→icon mapping, response parsing
- `weather_config.lua` — Auto-persisting key-value store (writes `weather_settings.lua` next to plugin dir)
- `weather_i18n.lua` — Translations (`vi`, `zh`, `ja`) with `gettext` fallback
- `statusline.lua` — Configurable status line for KOReader reader footer (same pattern as lunar.koplugin's statusline)
- `weathercards/` — Individual card modules for the full-screen weather view
- `resources/google-weather/*.svg` — 23 weather condition icons (48×48, no `<text>`/`<defs>`/`<linearGradient>`)
- `resources/arrow_*.svg` — 8 wind direction arrows

## KOReader widget quirks (critical)
- **`FrameContainer:getSize()` IGNORES `width`/`height`/`dimen`** — always calculates from `self[1]:getSize()` + padding + borders. Use `CenterContainer{ dimen = Geom:new{ w = ..., h = ... } }` when fixed size is needed (inherits `WidgetContainer:getSize()` which checks `self.dimen` first).
- **`ScrollableContainer`** subtracts `3 * scroll_bar_width` from viewport when vertical scrollbar appears. Inner content width must be `sw - sbw` to prevent horizontal scrollbar.
- **`FitWidthContainer`** (custom, `weatherview.lua:36-45`): `InputContainer:extend` that reports fixed `fw` width but delegates height to child. Use when content must not overflow scrollable viewport.
- **`LeftContainer`** left-aligns child within `dimen` (no horizontal shift). `RightContainer` right-aligns. Both vertically center the child.
- **SVG rules**: `ImageWidget` with SVGs needs `alpha = true, is_icon = true`; no `<text>`, `<defs>`, `<linearGradient>`, or `<stop>` elements (not supported by KOReader renderer).
- **`show_parent`** must be set for `UIManager:setDirty` to propagate through scrollable views. When a ScrollableContainer lives inside a Zen UI home page, `show_parent` must point to the window-level Menu widget (`ctx.menu`).
- **`InputContainer:getSize()`** returns `self.dimen` (allocated size), NOT actual child content. Override it to return `self[1]:getSize()` when parent containers (e.g., ScrollableContainer:initState) need the true rendered height.
- **`ScrollableContainer`: wrap body in `ScrollableContainer{ dimen = Geom:new{ w=content_w, h=body_h }, scroll_bar_width=0 }`, set `show_parent = menu`, call `initState()`, then nil `_v_scroll_bar` to avoid drawing artifacts from the zero-width bar.

## Lua constraints (5.1)
- No trailing commas in function call arguments (`f(1, 2,)` → syntax error)
- No `continue`; use `goto` or restructure
- **`_` is reserved for gettext** (`local _ = require("weather_i18n")`). Never use `_` as a for-loop placeholder — use `__` instead, or `_` will be shadowed by a number and `_("...")` will crash with "attempt to call a number value".

## Providers
- `providers/visualcrossing.lua` — Visual Crossing Weather API (`weather.visualcrossing.com`). Free tier: 1,000 records/day, need API key, ≤15 days forecast, no AQI. Single endpoint `/timeline/LAT,LON` returns `currentConditions` + `days[]` (each with `hours[]`). Icon names (Dark Sky style) mapped to set-4 via `VISUALCROSSING_ICONS`. Wind in km/h (metric), temp in °C (metric). WMO_MAP for precipitation icons → `rain_prediction`. Open-Meteo AQI fallback via `weather_api.lua`.

## Provider recommendations (Asia)
- **Recommended**: Tomorrow.io and WeatherAPI.com — best accuracy/coverage in Asia per user experience. WeatherAPI uses IBM/The Weather Channel data with strong Asian coverage; Tomorrow.io uses proprietary AI models with good global performance.
- Open-Meteo (ECMWF official) is reliable but WeatherAPI/Tomorrow.io preferred for Asian locations.

## Styling conventions
- `snake_case` for locals and functions, `camelCase` for methods/widget members
- `Screen:scaleBySize()` for all sizing (never hardcode pixels)
- `Blitbuffer` for custom painting (`:paintRect`, `:paintRoundedRect`)
- `pcall(require, ...)` for optional modules (`socket.http`, `json`)

## API calls
- **Weather data**: `https://api.open-meteo.com/v1/forecast` (blocking `http.request(url)`)
- **Geocoding**: `https://geocoding-api.open-meteo.com/v1/search` (15s timeout, `http.request{url, timeout=15}`)
- **Auto-detect**: `http://ip-api.com/json/` (in `main.lua` only)
- URLs must be **URL-encoded** for special characters (`urlencode()` exists in `weatherapi.lua`; `weatherview.lua` has its own copy)

## Asynchronous patterns
- `Trapper:wrap(function() ... end)` for non-blocking coroutine-based flows (search, geocoding)
- `Trapper:info()` shows dismissable progress messages; returns `false` if dismissed
- `Trapper:clear()` closes the current Trapper InfoMessage
- Button callbacks from `ButtonDialog` / `InputDialog` run **outside** the Trapper coroutine — don't call `Trapper:info()` inside them

## Config
- `config.get(key, default)` / `config.set(key, val)` — auto-persists to `weather_settings.lua`
- Keys: `weather_latitude`, `weather_longitude`, `weather_location_name`, `weather_temp_unit`, `weather_forecast_days`

## Entrypoints
- **Menu**: `Weather:addToMainMenu()` at `main.lua:267`
- **Dispatcher**: `"weather_open"` → event `"WeatherOpen"` → `Weather:onWeatherOpen()` at `main.lua:26`
- **View**: `WeatherView:new{ lat, lon, temp_unit, forecast_days, location_name }` at `weatherview.lua:145`

## Miscellaneous
- Plugin is symlinked from `~/.config/koreader/plugins/weather.koplugin/` to this repo — edits take immediate effect
- No `LICENSE` file; license declared as "GNU AFFERO GENERAL PUBLIC" in `info.lua`
