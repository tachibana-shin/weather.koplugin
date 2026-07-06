# Weather.koplugin

Full-screen weather widget for KOReader.

Runs standalone as a KOReader plugin (open via menu or gesture). When [Zen UI](https://github.com/AnthonyGress/zen_ui.koplugin) is installed, it additionally registers 8 home screen cards and a status line item.

## Screenshots
<img width="425" height="707" alt="image" src="https://github.com/user-attachments/assets/cf24f5b4-65fa-49e3-b0d7-a76f4cb3746a" />
<img width="425" height="708" alt="image" src="https://github.com/user-attachments/assets/f5b835aa-d642-4b70-b166-bc2eaa6e69a3" />
<img width="425" height="708" alt="image" src="https://github.com/user-attachments/assets/7732b631-bfbb-4c2d-90ad-08b76d7efb36" />

<!-- TODO: add screenshots -->

Support ZenUI status bar and Home:

<img width="426" height="705" alt="image" src="https://github.com/user-attachments/assets/907eb0db-cb8d-4447-b95f-1249ebee37df" />
<img width="427" height="705" alt="image" src="https://github.com/user-attachments/assets/290eaa07-d578-4ed5-a112-8a6daf6c300d" />
<img width="425" height="457" alt="image" src="https://github.com/user-attachments/assets/4e7ff1ea-16ff-4f11-9cdb-6129097f0642" />

Multi provider:

<img width="425" height="704" alt="image" src="https://github.com/user-attachments/assets/39f1229a-e5c3-4df6-975c-db1b1422cfd4" />


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

## License
Copyright (c) 2026-now [AGNU GPL](./LICENSE) Tachibana Shin

Thanks for [OpenCode](https://github.com/anomalyco/opencode)
