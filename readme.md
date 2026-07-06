# Weather.koplugin

Full-screen weather widget for KOReader.

Runs standalone as a KOReader plugin (open via menu or gesture). When [Zen UI](https://github.com/AnthonyGress/zen_ui.koplugin) is installed, it additionally registers 8 home screen cards and a status line item.

## Screenshots

<!-- TODO: add screenshots -->

## Features

- Multi-provider: Open-Meteo, WeatherAPI.com, IQAir, Tomorrow.io, Weatherbit, Visual Crossing
- Current conditions, hourly/daily forecasts, air quality, sun cycle, alerts
- Zen UI home cards (8 widgets) + configurable status line
- Persistent background auto-refresh (configurable interval)
- Search locations + auto-detect via IP
- Translations: vi, zh, ja

## Installation

1. Download `weather.koplugin.zip` from [Releases](https://github.com/tachibana-shin/weather.koplugin/releases)
2. Extract to KOReader's plugin directory (`koreader/plugins/` or `~/.config/koreader/plugins/`)

## Build from source

```sh
make zip      # lint + fetch icons + package
```
