local _ = require("weather_i18n")
local config = require("weather_config")

local M = {}

local WEATHERAPI_ICONS = {
    [1000] = "clear_day",
    [1003] = "partly_cloudy_day",
    [1006] = "mostly_cloudy_day",
    [1009] = "cloudy",
    [1012] = "haze_fog_dust_smoke",
    [1015] = "haze_fog_dust_smoke",
    [1018] = "haze_fog_dust_smoke",
    [1021] = "haze_fog_dust_smoke",
    [1024] = "haze_fog_dust_smoke",
    [1027] = "haze_fog_dust_smoke",
    [1030] = "haze_fog_dust_smoke",
    [1033] = "haze_fog_dust_smoke",
    [1036] = "haze_fog_dust_smoke",
    [1039] = "haze_fog_dust_smoke",
    [1042] = "haze_fog_dust_smoke",
    [1045] = "haze_fog_dust_smoke",
    [1048] = "haze_fog_dust_smoke",
    [1063] = "sunny_with_rain",
    [1066] = "snow_with_sunny",
    [1069] = "mixed_rain_snow",
    [1072] = "icy",
    [1087] = "isolated_thunderstorms",
    [1114] = "blowing_snow",
    [1117] = "blizzard",
    [1135] = "haze_fog_dust_smoke",
    [1147] = "icy",
    [1150] = "drizzle",
    [1153] = "drizzle",
    [1168] = "icy",
    [1171] = "icy",
    [1180] = "sunny_with_rain",
    [1183] = "rain_with_cloudy",
    [1186] = "showers_rain",
    [1189] = "showers_rain",
    [1192] = "heavy_rain",
    [1195] = "heavy_rain",
    [1198] = "mixed_rain_snow",
    [1201] = "mixed_rain_snow",
    [1204] = "mixed_rain_hail_sleet",
    [1207] = "mixed_rain_hail_sleet",
    [1210] = "snow_with_sunny",
    [1213] = "cloudy_with_snow",
    [1216] = "snow_with_cloudy",
    [1219] = "snow_with_cloudy",
    [1222] = "heavy_snow",
    [1225] = "heavy_snow",
    [1237] = "mixed_rain_hail_sleet",
    [1240] = "scattered_showers_day",
    [1243] = "showers_rain",
    [1246] = "heavy_rain",
    [1249] = "showers_snow",
    [1252] = "showers_snow",
    [1255] = "scattered_snow_showers_day",
    [1258] = "scattered_snow_showers_day",
    [1261] = "mixed_rain_hail_sleet",
    [1264] = "mixed_rain_hail_sleet",
    [1273] = "isolated_thunderstorms",
    [1276] = "strong_thunderstorms",
    [1279] = "thunderstorms",
    [1282] = "strong_thunderstorms",
}

-- Map WeatherAPI codes to approximate WMO codes for rain_prediction
local WMO_MAP = {
    [1063]=61, [1066]=71, [1069]=65, [1072]=56,
    [1114]=75, [1117]=75,
    [1150]=51, [1153]=53, [1168]=56, [1171]=57,
    [1180]=61, [1183]=61, [1186]=63, [1189]=63,
    [1192]=65, [1195]=65, [1198]=66, [1201]=67,
    [1204]=65, [1207]=67, [1210]=71, [1213]=71,
    [1216]=73, [1219]=73, [1222]=75, [1225]=75,
    [1237]=77, [1240]=80, [1243]=81, [1246]=82,
    [1249]=85, [1252]=85, [1255]=85, [1258]=86,
    [1261]=77, [1264]=77, [1273]=95, [1276]=95,
    [1279]=85, [1282]=86,
}

local NIGHT_ICON_MAP = {
    clear_day = "clear_night",
    mostly_sunny = "mostly_clear_night",
    mostly_cloudy_day = "mostly_cloudy_night",
    partly_cloudy_day = "partly_cloudy_night",
    scattered_showers_day = "scattered_showers_night",
    scattered_snow_showers_day = "scattered_snow_showers_night",
    isolated_thunderstorms = "isolated_scattered_thunderstorms_night",
}

local function night_icon(day_icon)
    return NIGHT_ICON_MAP[day_icon] or day_icon
end

local WIND_DIRS = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" }

local function wind_direction_label(degrees)
    if not degrees then return "?" end
    local index = math.floor((degrees + 11.25) / 22.5) % 16 + 1
    return WIND_DIRS[index]
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

-- Simple AQI from raw µg/m³ using EPA breakpoints
local function calculate_aqi(pm25, pm10, o3, no2, so2)
    local function epa_aqi_linear(c, bp_lo, bp_hi, aqi_lo, aqi_hi)
        return math.floor((aqi_hi - aqi_lo) / (bp_hi - bp_lo) * (c - bp_lo) + aqi_lo + 0.5)
    end

    local function epa_pm25(c)
        if c < 0 then return nil end
        if c <= 12.0 then return epa_aqi_linear(c, 0, 12.0, 0, 50)
        elseif c <= 35.4 then return epa_aqi_linear(c, 12.1, 35.4, 51, 100)
        elseif c <= 55.4 then return epa_aqi_linear(c, 35.5, 55.4, 101, 150)
        elseif c <= 150.4 then return epa_aqi_linear(c, 55.5, 150.4, 151, 200)
        elseif c <= 250.4 then return epa_aqi_linear(c, 150.5, 250.4, 201, 300)
        elseif c <= 500.4 then return epa_aqi_linear(c, 250.5, 500.4, 301, 500)
        else return 500 end
    end

    local function epa_pm10(c)
        if c < 0 then return nil end
        if c <= 54 then return epa_aqi_linear(c, 0, 54, 0, 50)
        elseif c <= 154 then return epa_aqi_linear(c, 55, 154, 51, 100)
        elseif c <= 254 then return epa_aqi_linear(c, 155, 254, 101, 150)
        elseif c <= 354 then return epa_aqi_linear(c, 255, 354, 151, 200)
        elseif c <= 424 then return epa_aqi_linear(c, 355, 424, 201, 300)
        elseif c <= 604 then return epa_aqi_linear(c, 425, 604, 301, 500)
        else return 500 end
    end

    local function epa_o3(c)
        if c < 0 then return nil end
        if c <= 54 then return epa_aqi_linear(c, 0, 54, 0, 50)
        elseif c <= 70 then return epa_aqi_linear(c, 55, 70, 51, 100)
        elseif c <= 85 then return epa_aqi_linear(c, 71, 85, 101, 150)
        elseif c <= 105 then return epa_aqi_linear(c, 86, 105, 151, 200)
        elseif c <= 200 then return epa_aqi_linear(c, 106, 200, 201, 300)
        else return 300 end
    end

    local function epa_no2(c)
        if c < 0 then return nil end
        if c <= 53 then return epa_aqi_linear(c, 0, 53, 0, 50)
        elseif c <= 100 then return epa_aqi_linear(c, 54, 100, 51, 100)
        elseif c <= 360 then return epa_aqi_linear(c, 101, 360, 101, 150)
        elseif c <= 649 then return epa_aqi_linear(c, 361, 649, 151, 200)
        elseif c <= 1249 then return epa_aqi_linear(c, 650, 1249, 201, 300)
        elseif c <= 2049 then return epa_aqi_linear(c, 1250, 2049, 301, 500)
        else return 500 end
    end

    local function epa_so2(c)
        if c < 0 then return nil end
        if c <= 35 then return epa_aqi_linear(c, 0, 35, 0, 50)
        elseif c <= 75 then return epa_aqi_linear(c, 36, 75, 51, 100)
        elseif c <= 185 then return epa_aqi_linear(c, 76, 185, 101, 150)
        elseif c <= 304 then return epa_aqi_linear(c, 186, 304, 151, 200)
        elseif c <= 604 then return epa_aqi_linear(c, 305, 604, 201, 300)
        elseif c <= 1004 then return epa_aqi_linear(c, 605, 1004, 301, 500)
        else return 500 end
    end

    local aqis = {
        pm25 = pm25 and epa_pm25(pm25),
        pm10 = pm10 and epa_pm10(pm10),
        o3 = o3 and epa_o3(o3),
        no2 = no2 and epa_no2(no2),
        so2 = so2 and epa_so2(so2),
    }

    local overall = 0
    for __, v in pairs(aqis) do
        if v and v > overall then overall = v end
    end
    return overall, aqis
end

local function parse_hour_time(time_str)
    -- time is "2024-01-15 00:00" format from weatherapi
    local h = tonumber((time_str:match("%-(%d%d):%d%d$")))
    if not h then
        h = tonumber((time_str:match("(%d%d):%d%d")))
    end
    return h
end

function M.fetch(lat, lon, temp_unit, forecast_days, wind_unit, precip_unit)
    temp_unit = temp_unit or "celsius"
    forecast_days = forecast_days or 7
    wind_unit = wind_unit or "kmh"

    local api_key = config.get("weather_weatherapi_key", "")
    if not api_key or api_key == "" then
        return nil, _("WeatherAPI.com key not set")
    end

    local ok, http = pcall(require, "socket.http")
    if not ok then
        return nil, "HTTP module not available"
    end

    local url = "https://api.weatherapi.com/v1/forecast.json"
        .. "?key=" .. api_key
        .. "&q=" .. tostring(lat) .. "," .. tostring(lon)
        .. "&days=" .. tostring(math.min(forecast_days, 14))
        .. "&aqi=yes"
        .. "&alerts=no"

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
        return nil, (data.error.message or tostring(data.error.code or "API error"))
    end

    local result = {}
    local loc = data.location
    if loc then
        result.location_name = loc.name
        result.timezone = loc.tz_id
    end

    local current = data.current
    if current then
        local code = current.condition and current.condition.code
        local icon_name = code and WEATHERAPI_ICONS[code] or "cloudy"
        local cond_text = current.condition and current.condition.text or "?"
        if not current.is_day or current.is_day == 0 then
            icon_name = night_icon(icon_name)
        end

        local wind_speed
        if wind_unit == "ms" then
            wind_speed = current.wind_kph / 3.6
        elseif wind_unit == "mph" then
            wind_speed = current.wind_kph / 1.609
        elseif wind_unit == "knots" then
            wind_speed = current.wind_kph / 1.852
        else
            wind_speed = current.wind_kph
        end

        local t, feels, dew, hi, wc
        if temp_unit == "fahrenheit" then
            t = current.temp_f
            feels = current.feelslike_f
            dew = current.dewpoint_f
            hi = current.heatindex_f
            wc = current.windchill_f
        else
            t = current.temp_c
            feels = current.feelslike_c
            dew = current.dewpoint_c
            hi = current.heatindex_c
            wc = current.windchill_c
        end

        result.current = {
            temperature = t,
            apparent_temperature = feels,
            humidity = current.humidity,
            dew_point = dew,
            weather_code = code or 0,
            weather_text = cond_text,
            weather_icon = icon_name,
            wind_speed = wind_speed,
            wind_direction = current.wind_degree,
            wind_label = wind_direction_label(current.wind_degree),
            pressure = current.pressure_mb,
            heat_index = hi,
            wind_chill = wc,
            is_day = current.is_day,
        }

        -- Override icon for extreme heat/cold
        if result.current.heat_index and result.current.heat_index >= 30 then
            result.current.weather_icon = "very_hot"
            result.current.weather_text = _("Too hot")
        elseif result.current.wind_chill and result.current.wind_chill <= 0 then
            result.current.weather_icon = "very_cold"
            result.current.weather_text = _("Too cold")
        end
    else
        return nil, "No current weather data in response"
    end

    local forecast = data.forecast
    if forecast and forecast.forecastday and #forecast.forecastday > 0 then
        local today_str = os.date("%Y-%m-%d")
        local weekdays = { _("Sun"), _("Mon"), _("Tue"), _("Wed"), _("Thu"), _("Fri"), _("Sat") }
        local english_weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

        result.daily = {}
        result.hourly = {}

        for day_idx, day_data in ipairs(forecast.forecastday) do
            local date_str = day_data.date
            local day = day_data.day
            local astro = day_data.astro
            local cond = day.condition
            local code = cond and cond.code
            local icon_name = code and WEATHERAPI_ICONS[code] or "cloudy"
            local cond_text = cond and cond.text or "?"

            local parts = {}
            for part in date_str:gmatch("[%d]+") do
                table.insert(parts, tonumber(part))
            end

            local day_label
            if date_str == today_str then
                day_label = _("Today")
            else
                local weekday_num
                if #parts >= 3 then
                    weekday_num = os.date("*t", os.time { year = parts[1], month = parts[2], day = parts[3] }).wday
                end
                if weekday_num then
                    day_label = weekdays[weekday_num] or english_weekdays[weekday_num] or date_str
                else
                    day_label = date_str
                end
            end

            local temp_max, temp_min
            if temp_unit == "fahrenheit" then
                temp_max = day.maxtemp_f
                temp_min = day.mintemp_f
            else
                temp_max = day.maxtemp_c
                temp_min = day.mintemp_c
            end

            local maxwind
            if wind_unit == "ms" then
                maxwind = day.maxwind_kph / 3.6
            elseif wind_unit == "mph" then
                maxwind = day.maxwind_kph / 1.609
            elseif wind_unit == "knots" then
                maxwind = day.maxwind_kph / 1.852
            else
                maxwind = day.maxwind_kph
            end

            table.insert(result.daily, {
                date = date_str,
                day_label = day_label,
                temp_max = temp_max,
                temp_min = temp_min,
                weather_code = code or 0,
                weather_icon = icon_name,
                weather_text = cond_text,
                precip_sum = day.totalprecip_mm,
                precip_prob = day.daily_chance_of_rain or 0,
                uv_index = day.uv,
                wind_max = maxwind,
                sunrise = astro and astro.sunrise or "",
                sunset = astro and astro.sunset or "",
            })

            -- Hourly data
            if day_data.hour and #day_data.hour > 0 then
                for _, h in ipairs(day_data.hour) do
                    local h_code = h.condition and h.condition.code
                    local h_icon = h_code and WEATHERAPI_ICONS[h_code] or "cloudy"
                    local h_text = h.condition and h.condition.text or "?"
                    local h_str = h.time or ""
                    local h_hour = parse_hour_time(h_str)

                    -- Only include hours from now onward
                    if day_idx == 1 then
                        local now_ts = os.time()
                        local current_hour = os.date("*t", now_ts)
                        local h_ts = os.time { year = parts[1], month = parts[2], day = parts[3], hour = h_hour or 0 }
                        if h_ts < os.time { year = current_hour.year, month = current_hour.month, day = current_hour.day, hour = current_hour.hour } then
                            goto continue
                        end
                    end

                    local is_night = h_hour and (h_hour < 6 or h_hour >= 18)
                    if is_night then
                        h_icon = night_icon(h_icon)
                    end

                    local hour_label = h_hour and string.format("%02d:00", h_hour) or h_str

                    local h_temp
                    if temp_unit == "fahrenheit" then
                        h_temp = h.temp_f
                    else
                        h_temp = h.temp_c
                    end

                    local h_wind
                    if wind_unit == "ms" then
                        h_wind = h.wind_kph / 3.6
                    elseif wind_unit == "mph" then
                        h_wind = h.wind_kph / 1.609
                    elseif wind_unit == "knots" then
                        h_wind = h.wind_kph / 1.852
                    else
                        h_wind = h.wind_kph
                    end

                    table.insert(result.hourly, {
                        time = hour_label,
                        temperature = h_temp,
                        humidity = h.humidity,
                        weather_code = h_code or 0,
                        weather_icon = h_icon,
                        weather_text = h_text,
                        precip_prob = h.chance_of_rain or 0,
                        precip = h.precip_mm or 0,
                        wind_speed = h_wind,
                        wind_direction = h.wind_degree,
                        is_night = is_night,
                    })
                    if #result.hourly >= 24 then break end
                    ::continue::
                end
            end
        end
    end

    if result.current and result.hourly then
        -- Map weather codes to approximate WMO for rain_prediction
        for _, h in ipairs(result.hourly) do
            if WMO_MAP[h.weather_code] then
                h.weather_code = WMO_MAP[h.weather_code]
            end
        end
        result.current.precip_prediction, result.current.precip_is_snow = rain_prediction(result.hourly)
    end

    -- Air quality
    if current and current.air_quality then
        local aq = current.air_quality
        local pm25 = aq.pm2_5
        local pm10 = aq.pm10
        local o3 = aq.o3
        local no2 = aq.no2
        local so2 = aq.so2

        local overall_aqi, component_aqis = calculate_aqi(pm25, pm10, o3, no2, so2)

        result.air_quality = {
            aqi = overall_aqi,
            components = {
                pm2_5 = { aqi = component_aqis and component_aqis.pm25 or 0, raw = pm25 },
                pm10  = { aqi = component_aqis and component_aqis.pm10 or 0, raw = pm10 },
                no2   = { aqi = component_aqis and component_aqis.no2 or 0, raw = no2 },
                o3    = { aqi = component_aqis and component_aqis.o3 or 0, raw = o3 },
                so2   = { aqi = component_aqis and component_aqis.so2 or 0, raw = so2 },
            },
            pollutants = {
                co = aq.co,
                dust = nil,
                ammonia = nil,
                aerosol_optical_depth = nil,
            },
            pollen = {},
        }
    end

    return result, nil
end

return M
