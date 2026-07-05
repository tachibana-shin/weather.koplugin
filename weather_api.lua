local _ = require("weather_i18n")
local config = require("weather_config")

local M = {}

local WMO_CODES = {
    [0]  = { icon = "clear_day",              text = _("Clear sky") },
    [1]  = { icon = "mostly_sunny",           text = _("Mainly clear") },
    [2]  = { icon = "partly_cloudy_day",      text = _("Partly cloudy") },
    [3]  = { icon = "cloudy",                 text = _("Overcast") },
    [45] = { icon = "haze_fog_dust_smoke",    text = _("Foggy") },
    [48] = { icon = "haze_fog_dust_smoke",    text = _("Rime fog") },
    [51] = { icon = "drizzle",                text = _("Light drizzle") },
    [53] = { icon = "drizzle",                text = _("Moderate drizzle") },
    [55] = { icon = "rain_with_cloudy",       text = _("Dense drizzle") },
    [56] = { icon = "icy",                    text = _("Light freezing drizzle") },
    [57] = { icon = "icy",                    text = _("Dense freezing drizzle") },
    [61] = { icon = "cloudy_with_rain",       text = _("Slight rain") },
    [63] = { icon = "showers_rain",           text = _("Moderate rain") },
    [65] = { icon = "heavy_rain",             text = _("Heavy rain") },
    [66] = { icon = "mixed_rain_snow",        text = _("Light freezing rain") },
    [67] = { icon = "icy",                    text = _("Heavy freezing rain") },
    [71] = { icon = "cloudy_with_snow",       text = _("Slight snow") },
    [73] = { icon = "snow_with_cloudy",       text = _("Moderate snow") },
    [75] = { icon = "blizzard",               text = _("Heavy snow") },
    [77] = { icon = "flurries",               text = _("Snow grains") },
    [80] = { icon = "scattered_showers_day",  text = _("Slight rain showers") },
    [81] = { icon = "scattered_showers_day",  text = _("Moderate rain showers") },
    [82] = { icon = "heavy_rain",             text = _("Violent rain showers") },
    [85] = { icon = "showers_snow",           text = _("Slight snow showers") },
    [86] = { icon = "scattered_snow_showers_day", text = _("Heavy snow showers") },
    [95] = { icon = "isolated_thunderstorms", text = _("Thunderstorm") },
    [96] = { icon = "sleet_hail",             text = _("Thunderstorm with slight hail") },
    [99] = { icon = "strong_thunderstorms",   text = _("Thunderstorm with heavy hail") },
}

local NIGHT_ICONS = {
    clear_day = "clear_night",
    mostly_sunny = "mostly_clear_night",
    partly_cloudy_day = "partly_cloudy_night",
    scattered_showers_day = "scattered_showers_night",
    scattered_snow_showers_day = "scattered_snow_showers_night",
    isolated_thunderstorms = "isolated_scattered_thunderstorms_night",
}

function M.getWeatherInfo(wmo_code)
    return WMO_CODES[wmo_code] or { icon = "cloudy", text = "?" }
end

function M.getNightIcon(day_icon)
    return NIGHT_ICONS[day_icon] or day_icon
end

local WIND_DIRS = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" }

function M.windDirectionLabel(degrees)
    if not degrees then return "?" end
    local index = math.floor((degrees + 11.25) / 22.5) % 16 + 1
    return WIND_DIRS[index]
end

function M.uvLabel(index)
    if not index then return "?" end
    if index <= 2 then return _("Low")
    elseif index <= 5 then return _("Moderate")
    elseif index <= 7 then return _("High")
    elseif index <= 10 then return _("Very High")
    else return _("Extreme") end
end

local WIND_LABELS = { kmh = "km/h", ms = "m/s", mph = "mph", knots = "knots" }
local PRESSURE_LABELS = { hPa = "hPa", inHg = "inHg", mmHg = "mmHg" }
local AQI_COLORS = {
    { max = 20,  label = _("Very Low"),   r = 89,  g = 185, b = 89  },
    { max = 40,  label = _("Low"),        r = 157, g = 202, b = 75  },
    { max = 60,  label = _("Medium"),     r = 255, g = 210, b = 67  },
    { max = 80,  label = _("High"),       r = 255, g = 155, b = 67  },
    { max = 100, label = _("Very High"),  r = 220, g = 70,  b = 70  },
    { max = nil, label = _("Extreme"),    r = 170, g = 50,  b = 50  },
}

function M.aqiLabel(aqi)
    if not aqi then return _("N/A"), 200, 200, 200 end
    for __, entry in ipairs(AQI_COLORS) do
        if aqi <= (entry.max or math.huge) then
            return entry.label, entry.r, entry.g, entry.b
        end
    end
    return _("Extreme"), 170, 50, 50
end

function M.windUnitLabel()
    return WIND_LABELS[config.get("weather_wind_unit", "kmh")] or "km/h"
end

function M.pressureDisplay(hpa)
    if not hpa then return nil end
    local unit = config.get("weather_pressure_unit", "hPa")
    if unit == "inHg" then
        return string.format("%.2f inHg", hpa * 0.02953)
    elseif unit == "mmHg" then
        return string.format("%.0f mmHg", hpa * 0.75006)
    end
    return string.format("%.0f hPa", hpa)
end

function M.precipUnitLabel()
    return config.get("weather_precip_unit", "mm") == "inch" and _("inch") or "mm"
end

function M.pressureUnitLabel()
    return PRESSURE_LABELS[config.get("weather_pressure_unit", "hPa")] or "hPa"
end

function M.pressureConvert(hpa)
    local unit = config.get("weather_pressure_unit", "hPa")
    if unit == "inHg" then return hpa * 0.02953
    elseif unit == "mmHg" then return hpa * 0.75006
    end
    return hpa
end

local DataStorage = require("datastorage")
local cache_file = DataStorage:getDataDir() .. "/weather_cache.json"

function M.cacheSave(data)
    local ok, JSON = pcall(require, "json")
    if not ok then return end
    data._cached_at = os.time()
    local ok_encode, str = pcall(JSON.encode, data)
    if not ok_encode or not str then return end
    local f = io.open(cache_file, "w")
    if not f then return end
    f:write(str)
    f:close()
end

function M.cacheLoad()
    local f = io.open(cache_file, "r")
    if not f then return nil end
    local str = f:read("*a")
    f:close()
    if not str or #str == 0 then return nil end
    local ok, JSON = pcall(require, "json")
    if not ok then return nil end
    local ok_decode, data = pcall(JSON.decode, str)
    if not ok_decode or not data then return nil end
    return data
end

function M.cacheAge()
    local f = io.open(cache_file, "r")
    if not f then return nil end
    local str = f:read("*a")
    f:close()
    if not str or #str == 0 then return nil end
    local ok, JSON = pcall(require, "json")
    if not ok then return nil end
    local ok_decode, data = pcall(JSON.decode, str)
    if not ok_decode or not data or not data._cached_at then return nil end
    return os.difftime(os.time(), data._cached_at)
end

local PROVIDERS = {
    openmeteo = "providers/openmeteo",
    weatherapi = "providers/weatherapi",
}

function M.fetch(lat, lon, temp_unit, forecast_days, wind_unit, precip_unit)
    local provider_name = config.get("weather_provider", "openmeteo")
    local modpath = PROVIDERS[provider_name]
    if not modpath then
        return nil, "Unknown weather provider: " .. tostring(provider_name)
    end
    local ok, provider = pcall(require, modpath)
    if not ok then
        return nil, "Failed to load provider: " .. tostring(provider_name)
    end
    return provider.fetch(lat, lon, temp_unit, forecast_days, wind_unit, precip_unit)
end

return M
