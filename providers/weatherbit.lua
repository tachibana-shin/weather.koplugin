local _ = require("weather_i18n")
local config = require("weather_config")

local M = {}

local WEATHERBIT_ICONS = {
    [200] = "isolated_thunderstorms",
    [201] = "strong_thunderstorms",
    [202] = "strong_thunderstorms",
    [233] = "sleet_hail",
    [301] = "drizzle",
    [302] = "drizzle",
    [310] = "icy",
    [311] = "icy",
    [320] = "mixed_rain_snow",
    [321] = "mixed_rain_snow",
    [322] = "mixed_rain_snow",
    [400] = "cloudy_with_snow",
    [401] = "snow_with_cloudy",
    [402] = "heavy_snow",
    [410] = "flurries",
    [420] = "cloudy_with_snow",
    [421] = "snow_with_cloudy",
    [430] = "blowing_snow",
    [500] = "sunny_with_rain",
    [501] = "showers_rain",
    [502] = "heavy_rain",
    [511] = "mixed_rain_snow",
    [512] = "icy",
    [520] = "scattered_showers_day",
    [521] = "showers_rain",
    [522] = "heavy_rain",
    [600] = "mixed_rain_snow",
    [601] = "mixed_rain_snow",
    [602] = "mixed_rain_snow",
    [610] = "mixed_rain_hail_sleet",
    [611] = "mixed_rain_hail_sleet",
    [612] = "mixed_rain_hail_sleet",
    [621] = "mixed_rain_snow",
    [622] = "mixed_rain_snow",
    [623] = "mixed_rain_snow",
    [700] = "haze_fog_dust_smoke",
    [721] = "haze_fog_dust_smoke",
    [741] = "icy",
    [751] = "haze_fog_dust_smoke",
    [800] = "clear_day",
    [801] = "mostly_sunny",
    [802] = "partly_cloudy_day",
    [803] = "mostly_cloudy_day",
    [804] = "cloudy",
}

local WMO_MAP = {
    [200]=95, [201]=95, [202]=95, [233]=96,
    [301]=53, [302]=55, [310]=56, [311]=56,
    [320]=77, [321]=77, [322]=77,
    [400]=71, [401]=73, [402]=75, [410]=77, [420]=71, [421]=73, [430]=75,
    [500]=61, [501]=63, [502]=65,
    [511]=66, [512]=67,
    [520]=80, [521]=81, [522]=82,
    [600]=66, [601]=66, [602]=67,
    [610]=77, [611]=77, [612]=77,
    [621]=66, [622]=66, [623]=67,
    [700]=45, [721]=45, [741]=48, [751]=45,
    [800]=0, [801]=1, [802]=2, [803]=3, [804]=3,
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

local function convert_wind(ms, wind_unit)
    if wind_unit == "kmh" then
        return ms * 3.6
    elseif wind_unit == "mph" then
        return ms * 2.237
    elseif wind_unit == "knots" then
        return ms * 1.944
    end
    return ms
end

local function convert_temp(c, temp_unit)
    if temp_unit == "fahrenheit" then
        return c * 9 / 5 + 32
    end
    return c
end

function M.fetch(lat, lon, temp_unit, forecast_days, wind_unit)
    temp_unit = temp_unit or "celsius"
    forecast_days = forecast_days or 7
    wind_unit = wind_unit or "kmh"

    local api_key = config.get("weather_weatherbit_key", "")
    if not api_key or api_key == "" then
        return nil, _("Weatherbit API key not set")
    end

    local ok, http = pcall(require, "socket.http")
    if not ok then
        return nil, "HTTP module not available"
    end

    local days = math.min(forecast_days, 16)

    -- Current weather + AQI
    local current_url = "https://api.weatherbit.io/v2.0/current"
        .. "?lat=" .. tostring(lat)
        .. "&lon=" .. tostring(lon)
        .. "&key=" .. api_key
        .. "&units=M"

    local body, code = http.request(current_url)
    if code ~= 200 then
        return nil, "HTTP " .. tostring(code) .. ": " .. tostring((body or ""):sub(1, 200))
    end
    if not body or #body == 0 then
        return nil, "Empty current weather response"
    end

    local ok_json, JSON = pcall(require, "json")
    if not ok_json then
        return nil, "JSON module not available"
    end

    local ok_decode, current_data = pcall(JSON.decode, body)
    if not ok_decode or not current_data or not current_data.data or #current_data.data == 0 then
        return nil, "No current weather data in response"
    end

    local cur = current_data.data[1]
    local cur_code = cur.weather and cur.weather.code
    local icon_name = cur_code and WEATHERBIT_ICONS[cur_code] or "cloudy"
    local cond_text = cur.weather and cur.weather.description or "?"
    local is_day = cur.pod == "d"
    if not is_day then
        icon_name = night_icon(icon_name)
    end

    local result = {}
    result.location_name = cur.city_name
    local country = cur.country_code
    if country then
        result.location_name = result.location_name .. ", " .. country
    end
    result.timezone = cur.timezone

    result.current = {
        temperature = convert_temp(cur.temp, temp_unit),
        apparent_temperature = cur.app_temp and convert_temp(cur.app_temp, temp_unit),
        humidity = cur.rh,
        dew_point = cur.dewpt and convert_temp(cur.dewpt, temp_unit),
        weather_code = cur_code or 0,
        weather_text = cond_text,
        weather_icon = icon_name,
        wind_speed = convert_wind(cur.wind_spd or 0, wind_unit),
        wind_direction = cur.wind_dir,
        wind_label = wind_direction_label(cur.wind_dir),
        pressure = cur.slp or cur.pres,
        heat_index = nil,
        wind_chill = nil,
        is_day = is_day and 1 or 0,
        visibility = cur.vis,
        uv_index = cur.uv,
        cloud_cover = cur.clouds,
    }

    -- Heat index / wind chill from feels_like
    if cur.app_temp then
        local at = convert_temp(cur.app_temp, temp_unit)
        local t = result.current.temperature
        if at >= t then
            result.current.heat_index = at
        else
            result.current.wind_chill = at
        end
    end

    if result.current.heat_index and result.current.heat_index >= 30 then
        result.current.weather_icon = "very_hot"
        result.current.weather_text = _("Too hot")
    elseif result.current.wind_chill and result.current.wind_chill <= 0 then
        result.current.weather_icon = "very_cold"
        result.current.weather_text = _("Too cold")
    end

    -- Daily forecast
    local daily_url = "https://api.weatherbit.io/v2.0/forecast/daily"
        .. "?lat=" .. tostring(lat)
        .. "&lon=" .. tostring(lon)
        .. "&key=" .. api_key
        .. "&units=M"
        .. "&days=" .. tostring(days)

    body, code = http.request(daily_url)
    if code == 200 and body and #body > 0 then
        local ok_dd, daily_data = pcall(JSON.decode, body)
        if ok_dd and daily_data and daily_data.data and #daily_data.data > 0 then
            local today_str = os.date("%Y-%m-%d")
            local weekdays = { _("Sun"), _("Mon"), _("Tue"), _("Wed"), _("Thu"), _("Fri"), _("Sat") }

            result.daily = {}
            for __, d in ipairs(daily_data.data) do
                local date_str = d.valid_date or d.datetime
                if not date_str or date_str < today_str then goto continue end

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
                    day_label = weekday_num and weekdays[weekday_num] or date_str
                end

                local d_code = d.weather and d.weather.code
                local d_icon = d_code and WEATHERBIT_ICONS[d_code] or "cloudy"
                local d_text = d.weather and d.weather.description or "?"

                table.insert(result.daily, {
                    date = date_str,
                    day_label = day_label,
                    temp_max = convert_temp(d.max_temp, temp_unit),
                    temp_min = convert_temp(d.min_temp, temp_unit),
                    weather_code = d_code or 0,
                    weather_icon = d_icon,
                    weather_text = d_text,
                    precip_sum = d.precip or 0,
                    precip_prob = d.pop or 0,
                    uv_index = d.uv,
                    wind_max = d.wind_gust_spd and convert_wind(d.wind_gust_spd, wind_unit),
                    sunrise = d.sunrise_ts and os.date("%H:%M", d.sunrise_ts) or "",
                    sunset = d.sunset_ts and os.date("%H:%M", d.sunset_ts) or "",
                })
                if #result.daily >= days then break end
                ::continue::
            end
        end
    end

    -- Hourly forecast
    local hourly_url = "https://api.weatherbit.io/v2.0/forecast/hourly"
        .. "?lat=" .. tostring(lat)
        .. "&lon=" .. tostring(lon)
        .. "&key=" .. api_key
        .. "&units=M"
        .. "&hours=" .. tostring(math.min(forecast_days * 24, 120))

    body, code = http.request(hourly_url)
    if code == 200 and body and #body > 0 then
        local ok_hd, hourly_data = pcall(JSON.decode, body)
        if ok_hd and hourly_data and hourly_data.data and #hourly_data.data > 0 then
            result.hourly = {}
            local current_hour = os.date("*t", os.time())
            local current_ts = os.time { year = current_hour.year, month = current_hour.month,
                day = current_hour.day, hour = current_hour.hour, min = 0 }

            for _, h in ipairs(hourly_data.data) do
                local ts_str = h.timestamp_local or ""
                local year, month, day, hour = ts_str:match("(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d)")
                if not year then
                    year, month, day, hour = ts_str:match("(%d%d%d%d)-(%d%d)-(%d%d) (%d%d)")
                end
                if year then
                    local h_ts = os.time { year = tonumber(year), month = tonumber(month),
                        day = tonumber(day), hour = tonumber(hour), min = 0 }
                    if h_ts < current_ts then goto continue_h end
                end

                local h_code = h.weather and h.weather.code
                local h_icon = h_code and WEATHERBIT_ICONS[h_code] or "cloudy"
                local h_text = h.weather and h.weather.description or "?"

                local is_night_h = h.pod == "n"
                if is_night_h then
                    h_icon = night_icon(h_icon)
                end

                local h_hour = hour and tonumber(hour)
                local hour_label = h_hour and string.format("%02d:00", h_hour) or ts_str

                table.insert(result.hourly, {
                    time = hour_label,
                    temperature = convert_temp(h.temp, temp_unit),
                    humidity = h.rh,
                    weather_code = h_code or 0,
                    weather_icon = h_icon,
                    weather_text = h_text,
                    precip_prob = h.pop or 0,
                    precip = h.precip or 0,
                    wind_speed = convert_wind(h.wind_spd or 0, wind_unit),
                    wind_direction = h.wind_dir,
                    is_night = is_night_h,
                })
                if #result.hourly >= 24 then break end
                ::continue_h::
            end
        end
    end

    -- Map weather codes to WMO for rain_prediction
    if result.current and result.hourly then
        for _, h in ipairs(result.hourly) do
            if WMO_MAP[h.weather_code] then
                h.weather_code = WMO_MAP[h.weather_code]
            end
        end
        result.current.precip_prediction, result.current.precip_is_snow = rain_prediction(result.hourly)
    end

    -- Air quality from current weather (free plan includes overall AQI)
    if cur.aqi then
        result.air_quality = { aqi = cur.aqi }
    end

    return result, nil
end

return M
