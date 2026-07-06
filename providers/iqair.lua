local _ = require("weather_i18n")
local config = require("weather_config")

local M = {}

-- Map OpenWeatherMap-style icon codes to our SVG icons
local ICON_MAP = {
    ["01d"] = "clear_day",
    ["01n"] = "clear_night",
    ["02d"] = "partly_cloudy_day",
    ["02n"] = "partly_cloudy_night",
    ["03d"] = "mostly_cloudy_day",
    ["03n"] = "mostly_cloudy_night",
    ["04d"] = "cloudy",
    ["04n"] = "cloudy",
    ["09d"] = "showers_rain",
    ["09n"] = "showers_rain",
    ["10d"] = "rain_with_cloudy",
    ["10n"] = "rain_with_cloudy",
    ["11d"] = "thunderstorms",
    ["11n"] = "thunderstorms",
    ["13d"] = "snow_with_cloudy",
    ["13n"] = "snow_with_cloudy",
    ["50d"] = "haze_fog_dust_smoke",
    ["50n"] = "haze_fog_dust_smoke",
}

-- Map OWM codes to approximate WMO codes for rain_prediction
local WMO_MAP = {
    ["09d"] = 80, ["09n"] = 80,
    ["10d"] = 61, ["10n"] = 61,
    ["11d"] = 95, ["11n"] = 95,
    ["13d"] = 73, ["13n"] = 73,
}

local RAIN_CODES = {
    [51]=true, [53]=true, [55]=true,
    [56]=true, [57]=true,
    [61]=true, [63]=true, [65]=true,
    [66]=true, [67]=true,
    [80]=true, [81]=true, [82]=true,
    [95]=true, [96]=true, [99]=true,
}

local SNOW_CODES = {
    [71]=true, [73]=true, [75]=true, [77]=true,
    [85]=true, [86]=true,
}

local function is_light_precip(code)
    return code == 51 or code == 53 or code == 55
        or code == 56 or code == 57
        or code == 61
        or code == 71 or code == 77
        or code == 80
        or code == 85
end

local function rain_prediction(hourly)
    if not hourly or #hourly == 0 then return nil end
    local count = 0
    local last_time = nil
    local is_snow = false
    local all_light = true
    for _, h in ipairs(hourly) do
        if RAIN_CODES[h.weather_code] or SNOW_CODES[h.weather_code] then
            count = count + 1
            last_time = h.time
            if SNOW_CODES[h.weather_code] then is_snow = true end
            if not is_light_precip(h.weather_code) then
                all_light = false
            end
        else
            break
        end
    end
    if count == 0 then return nil, nil end
    local label
    if is_snow then
        label = all_light and _("Slight snow") or _("Snow")
    else
        label = all_light and _("Slight rain") or _("Rain")
    end
    local text
    if count == 1 then
        text = string.format("%s %s", label, _("will stop soon"))
    elseif count >= #hourly then
        text = string.format("%s %s", label, _("will continue throughout the day"))
    else
        text = string.format("%s %s %s", label, _("will continue until"), last_time)
    end
    return text, is_snow
end

local WIND_DIRS = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" }

local function wind_direction_label(degrees)
    if not degrees then return "?" end
    local index = math.floor((degrees + 11.25) / 22.5) % 16 + 1
    return WIND_DIRS[index]
end

function M.fetch(lat, lon, temp_unit, _, wind_unit)
    temp_unit = temp_unit or "celsius"
    wind_unit = wind_unit or "kmh"

    local key = config.get("weather_iqair_key", "")
    if not key or key == "" then
        return nil, _("IQAir API key not set")
    end

    local ok, http = pcall(require, "socket.http")
    if not ok then
        return nil, "HTTP module not available"
    end

    local url = "https://api.airvisual.com/v2/nearest_city"
        .. "?lat=" .. tostring(lat)
        .. "&lon=" .. tostring(lon)
        .. "&key=" .. tostring(key)

    local body, code = http.request(url)
    if code ~= 200 then
        return nil, "HTTP " .. tostring(code) .. ": " .. tostring((body or ""):sub(1, 200))
    end
    if not body or #body == 0 then
        return nil, "Empty response"
    end

    local ok_json, JSON = pcall(require, "json")
    if not ok_json then
        return nil, "JSON module not available"
    end

    local ok_decode, data = pcall(JSON.decode, body)
    if not ok_decode or not data then
        return nil, "JSON parse error"
    end

    if data.status ~= "success" then
        local msg = "API error"
        if data.data and data.data.message then
            msg = data.data.message
        end
        return nil, msg
    end

    local d = data.data
    if not d then
        return nil, "No data in response"
    end

    local weather = d.current and d.current.weather
    local pollution = d.current and d.current.pollution

    if not weather then
        return nil, "No weather data in response"
    end

    local result = {}

    local icon_code = weather.ic or "01d"
    local icon_name = ICON_MAP[icon_code] or "cloudy"
    local is_night = icon_code:match("n$") and true or false

    local wmo_code = WMO_MAP[icon_code]

    -- Temperature conversion (IQAir returns Celsius)
    local t = weather.tp
    local hi = weather.heatIndex
    if temp_unit == "fahrenheit" then
        t = t and (t * 9/5 + 32) or nil
        hi = hi and (hi * 9/5 + 32) or nil
    end

    -- Wind speed conversion (IQAir returns m/s)
    local ws = weather.ws
    if ws then
        if wind_unit == "ms" then
            ws = ws
        elseif wind_unit == "mph" then
            ws = ws * 2.237
        elseif wind_unit == "knots" then
            ws = ws * 1.944
        else -- kmh
            ws = ws * 3.6
        end
    end

    result.current = {
        temperature = t,
        apparent_temperature = t,
        humidity = weather.hu,
        dew_point = nil,
        weather_code = wmo_code or 0,
        weather_text = "?",
        weather_icon = icon_name,
        wind_speed = ws,
        wind_direction = weather.wd,
        wind_label = wind_direction_label(weather.wd),
        pressure = weather.pr,
        heat_index = hi,
        wind_chill = nil,
        is_day = is_night and 0 or 1,
    }

    -- Populate AQI from pollution data
    if pollution and pollution.aqius then
        result.air_quality = {
            aqi = pollution.aqius,
        }
    end

    result.daily = {}
    result.hourly = {}

    if result.current and result.hourly then
        result.current.precip_prediction, result.current.precip_is_snow = rain_prediction(result.hourly)
    end

    if d.city then
        local parts = { d.city }
        if d.state then table.insert(parts, d.state) end
        if d.country then table.insert(parts, d.country) end
        result.location_name = table.concat(parts, ", ")
    end

    return result, nil
end

return M
