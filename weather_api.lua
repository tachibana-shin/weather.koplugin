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

-- NOAA Heat Index: temperature (°C), relative humidity (%)
local function heat_index(t_c, rh)
    if not t_c or not rh then return nil end
    local T = t_c * 9/5 + 32
    local R = rh
    local HI_f = 0.5 * (T + 61.0 + (T - 68.0) * 1.2 + R * 0.094)
    if HI_f < 80 then
        return (HI_f - 32) * 5/9
    end
    HI_f = -42.379 + 2.04901523*T + 10.14333127*R - 0.22475541*T*R
         - 0.00683783*T*T - 0.05481717*R*R + 0.00122874*T*T*R
         + 0.00085282*T*R*R - 0.00000199*T*T*R*R
    if R < 13 and T >= 80 and T <= 112 then
        HI_f = HI_f - ((13 - R) / 4) * math.sqrt((17 - math.abs(T - 95)) / 17)
    elseif R > 85 and T >= 80 and T <= 87 then
        HI_f = HI_f + ((R - 85) / 10) * ((87 - T) / 5)
    end
    return (HI_f - 32) * 5/9
end

-- NWS Wind Chill: temperature (°C), wind speed (km/h)
local function wind_chill(t_c, ws_kmh)
    if not t_c or not ws_kmh then return nil end
    if t_c > 10 or ws_kmh < 4.8 then return t_c end
    local T = t_c * 9/5 + 32
    local V = ws_kmh / 1.609
    local WC_f = 35.74 + 0.6215*T - 35.75*V^0.16 + 0.4275*T*V^0.16
    return (WC_f - 32) * 5/9
end

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

function M.uvLabel(index)
    if not index then return "?" end
    if index <= 2 then return _("Low")
    elseif index <= 5 then return _("Moderate")
    elseif index <= 7 then return _("High")
    elseif index <= 10 then return _("Very High")
    else return _("Extreme") end
end

function M.fetch(lat, lon, temp_unit, forecast_days, wind_unit, precip_unit)
    temp_unit = temp_unit or "celsius"
    forecast_days = forecast_days or 7
    wind_unit = wind_unit or "kmh"
    precip_unit = precip_unit or "mm"

    local ok, http = pcall(require, "socket.http")
    if not ok then
        return nil, "HTTP module not available"
    end

    local function urlencode(str)
        return str:gsub("([^%w%.%-])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    end

    local current_params = {
        "temperature_2m",
        "relative_humidity_2m",
        "apparent_temperature",
        "dew_point_2m",
        "weather_code",
        "wind_speed_10m",
        "wind_direction_10m",
        "surface_pressure",
        "is_day",
    }

    local hourly_params = {
        "temperature_2m",
        "relative_humidity_2m",
        "weather_code",
        "precipitation_probability",
        "precipitation",
        "wind_speed_10m",
        "wind_direction_10m",
    }

    local daily_params = {
        "temperature_2m_max",
        "temperature_2m_min",
        "weather_code",
        "precipitation_sum",
        "precipitation_probability_max",
        "uv_index_max",
        "wind_speed_10m_max",
        "sunrise",
        "sunset",
    }

    local url = "https://api.open-meteo.com/v1/forecast"
        .. "?latitude=" .. tostring(lat)
        .. "&longitude=" .. tostring(lon)
        .. "&current=" .. urlencode(table.concat(current_params, ","))
        .. "&hourly=" .. urlencode(table.concat(hourly_params, ","))
        .. "&daily=" .. urlencode(table.concat(daily_params, ","))
        .. "&timezone=auto"
        .. "&temperature_unit=" .. urlencode(temp_unit)
        .. "&forecast_days=" .. tostring(forecast_days)
        .. "&wind_speed_unit=" .. urlencode(wind_unit)
        .. "&precipitation_unit=" .. urlencode(precip_unit)

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

    if data.error then
        return nil, data.reason or "API error"
    end

    local result = {}

    local current = data.current
    if current then
        local wmo = M.getWeatherInfo(current.weather_code)
        result.current = {
            temperature = current.temperature_2m,
            apparent_temperature = current.apparent_temperature,
            humidity = current.relative_humidity_2m,
            dew_point = current.dew_point_2m,
            weather_code = current.weather_code,
            weather_text = wmo.text,
            weather_icon = wmo.icon,
            wind_speed = current.wind_speed_10m,
            wind_direction = current.wind_direction_10m,
            wind_label = M.windDirectionLabel(current.wind_direction_10m),
            pressure = current.surface_pressure,
            is_day = current.is_day,
        }
        if not current.is_day or current.is_day == 0 then
            result.current.weather_icon = M.getNightIcon(result.current.weather_icon)
        end

        local t_celsius = current.temperature_2m
        if temp_unit == "fahrenheit" then
            t_celsius = (t_celsius - 32) * 5/9
        end
        local hi = heat_index(t_celsius, current.relative_humidity_2m)
        local wc = wind_chill(t_celsius, current.wind_speed_10m)
        if temp_unit == "fahrenheit" then
            hi = hi and (hi * 9/5 + 32) or nil
            wc = wc and (wc * 9/5 + 32) or nil
        end
        result.current.heat_index = hi
        result.current.wind_chill = wc
        if hi and hi >= 30 then
            result.current.weather_icon = "very_hot"
            result.current.weather_text = _("Too hot")
        elseif wc and wc <= 0 then
            result.current.weather_icon = "very_cold"
            result.current.weather_text = _("Too cold")
        end
    end

    local hourly = data.hourly
    if hourly and hourly.time then
        local now_ts = os.time()
        local current_hour = os.date("*t", now_ts)
        current_hour.min = 0
        current_hour.sec = 0
        local current_hour_ts = os.time(current_hour)

        result.hourly = {}
        for i, t in ipairs(hourly.time) do
            local parts = {}
            for part in t:gmatch("[%d]+") do
                table.insert(parts, tonumber(part))
            end
            if #parts >= 2 then
                local ts = os.time { year = parts[1], month = parts[2], day = parts[3], hour = parts[4] or 0 }
                if ts >= current_hour_ts then
                    local wmo = M.getWeatherInfo(hourly.weather_code[i])
                    local is_night = parts[4] and (parts[4] < 6 or parts[4] >= 18)
                    local icon = is_night and M.getNightIcon(wmo.icon) or wmo.icon
                    local hour_str = string.format("%02d:00", parts[4] or 0)
                    table.insert(result.hourly, {
                        time = hour_str,
                        temperature = hourly.temperature_2m[i],
                        humidity = hourly.relative_humidity_2m[i],
                        weather_code = hourly.weather_code[i],
                        weather_icon = icon,
                        weather_text = wmo.text,
                        precip_prob = hourly.precipitation_probability[i],
                        precip = hourly.precipitation[i],
                        wind_speed = hourly.wind_speed_10m[i],
                        wind_direction = hourly.wind_direction_10m[i],
                        is_night = is_night,
                    })
                    if #result.hourly >= 24 then break end
                end
            end
        end
    end

    if result.current and result.hourly then
        result.current.precip_prediction, result.current.precip_is_snow = rain_prediction(result.hourly)
    end

    local daily = data.daily
    if daily and daily.time then
        local today_str = os.date("%Y-%m-%d")
        local weekdays = { _("Sun"), _("Mon"), _("Tue"), _("Wed"), _("Thu"), _("Fri"), _("Sat") }
        local english_weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

        result.daily = {}
        for i, t in ipairs(daily.time) do
            local wmo = M.getWeatherInfo(daily.weather_code[i])
            local parts = {}
            for part in t:gmatch("[%d]+") do
                table.insert(parts, tonumber(part))
            end
            local day_label
            if t == today_str then
                day_label = _("Today")
            else
                local weekday_num
                if #parts >= 3 then
                    weekday_num = os.date("*t", os.time { year = parts[1], month = parts[2], day = parts[3] }).wday
                end
                if weekday_num then
                    day_label = weekdays[weekday_num] or english_weekdays[weekday_num] or t
                else
                    day_label = t
                end
            end
            table.insert(result.daily, {
                date = t,
                day_label = day_label,
                temp_max = daily.temperature_2m_max[i],
                temp_min = daily.temperature_2m_min[i],
                weather_code = daily.weather_code[i],
                weather_icon = wmo.icon,
                weather_text = wmo.text,
                precip_sum = daily.precipitation_sum[i],
                precip_prob = daily.precipitation_probability_max[i],
                uv_index = daily.uv_index_max[i],
                wind_max = daily.wind_speed_10m_max[i],
                sunrise = daily.sunrise[i],
                sunset = daily.sunset[i],
            })
        end
    end

    result.timezone = data.timezone
    result.timezone_abbr = data.timezone_abbreviation

    -- Fetch air quality data
    local aqi_params = {
        "european_aqi",
        "european_aqi_pm2_5", "european_aqi_pm10",
        "european_aqi_nitrogen_dioxide",
        "european_aqi_ozone", "european_aqi_sulphur_dioxide",
        "pm2_5", "pm10", "nitrogen_dioxide", "ozone", "sulphur_dioxide",
        "carbon_monoxide", "dust", "ammonia", "aerosol_optical_depth",
        "alder_pollen", "birch_pollen", "grass_pollen",
        "mugwort_pollen", "olive_pollen", "ragweed_pollen",
    }
    local aqi_url = "https://air-quality-api.open-meteo.com/v1/air-quality"
        .. "?latitude=" .. tostring(lat)
        .. "&longitude=" .. tostring(lon)
        .. "&current=" .. urlencode(table.concat(aqi_params, ","))
    local aqi_body, aqi_code = http.request(aqi_url)
    if aqi_code == 200 and aqi_body and #aqi_body > 0 then
        local ok_aqi_decode, aqi_data = pcall(JSON.decode, aqi_body)
        if ok_aqi_decode and aqi_data and aqi_data.current then
            local c = aqi_data.current
            result.air_quality = {
                aqi = c.european_aqi,
                components = {
                    pm2_5 = { aqi = c.european_aqi_pm2_5, raw = c.pm2_5 },
                    pm10  = { aqi = c.european_aqi_pm10,  raw = c.pm10 },
                    no2   = { aqi = c.european_aqi_nitrogen_dioxide, raw = c.nitrogen_dioxide },
                    o3    = { aqi = c.european_aqi_ozone, raw = c.ozone },
                    so2   = { aqi = c.european_aqi_sulphur_dioxide, raw = c.sulphur_dioxide },
                },
                pollutants = {
                    co = c.carbon_monoxide,
                    dust = c.dust,
                    ammonia = c.ammonia,
                    aerosol_optical_depth = c.aerosol_optical_depth,
                },
                pollen = {
                    alder = c.alder_pollen,
                    birch = c.birch_pollen,
                    grass = c.grass_pollen,
                    mugwort = c.mugwort_pollen,
                    olive = c.olive_pollen,
                    ragweed = c.ragweed_pollen,
                },
            }
        end
    end

    return result, nil
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

return M
