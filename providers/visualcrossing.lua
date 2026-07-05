local _ = require("weather_i18n")
local config = require("weather_config")

local M = {}

local VISUALCROSSING_ICONS = {
    ["clear-day"] = "clear_day",
    ["clear-night"] = "clear_night",
    ["partly-cloudy-day"] = "partly_cloudy_day",
    ["partly-cloudy-night"] = "partly_cloudy_night",
    ["cloudy"] = "cloudy",
    ["fog"] = "haze_fog_dust_smoke",
    ["wind"] = "windy",
    ["rain"] = "rain_with_cloudy",
    ["sleet"] = "mixed_rain_snow",
    ["snow"] = "cloudy_with_snow",
    ["snow-showers-day"] = "scattered_snow_showers_day",
    ["snow-showers-night"] = "scattered_snow_showers_night",
    ["thunder-rain"] = "isolated_thunderstorms",
    ["thunder-showers-day"] = "isolated_thunderstorms",
    ["thunder-showers-night"] = "isolated_scattered_thunderstorms_night",
    ["rain-snow"] = "mixed_rain_snow",
    ["rain-snow-showers-day"] = "scattered_snow_showers_day",
    ["rain-snow-showers-night"] = "scattered_snow_showers_night",
    ["freezing-rain"] = "icy",
    ["freezing-rain-showers-day"] = "icy",
    ["freezing-rain-showers-night"] = "icy",
    ["hail"] = "sleet_hail",
    ["hail-day"] = "sleet_hail",
    ["hail-night"] = "sleet_hail",
    ["thunder-hail"] = "sleet_hail",
    ["thunder-hail-day"] = "sleet_hail",
    ["thunder-hail-night"] = "sleet_hail",
}

-- Map Visual Crossing icons to approximate WMO codes for rain_prediction
local WMO_MAP = {
    rain = 61,
    sleet = 66,
    snow = 71,
    ["snow-showers-day"] = 85,
    ["snow-showers-night"] = 85,
    ["thunder-rain"] = 95,
    ["thunder-showers-day"] = 95,
    ["thunder-showers-night"] = 95,
    ["rain-snow"] = 66,
    ["rain-snow-showers-day"] = 85,
    ["rain-snow-showers-night"] = 85,
    ["freezing-rain"] = 66,
    ["freezing-rain-showers-day"] = 66,
    ["freezing-rain-showers-night"] = 66,
    hail = 96,
    ["hail-day"] = 96,
    ["hail-night"] = 96,
    ["thunder-hail"] = 99,
    ["thunder-hail-day"] = 99,
    ["thunder-hail-night"] = 99,
}

local NIGHT_ICON_MAP = {
    ["clear-day"] = "clear_night",
    ["partly-cloudy-day"] = "partly_cloudy_night",
    ["snow-showers-day"] = "snow-showers-night",
    ["thunder-showers-day"] = "thunder-showers-night",
    ["rain-snow-showers-day"] = "rain-snow-showers-night",
    ["freezing-rain-showers-day"] = "freezing-rain-showers-night",
    ["hail-day"] = "hail-night",
    ["thunder-hail-day"] = "thunder-hail-night",
}

local function get_icon(icon_name)
    return VISUALCROSSING_ICONS[icon_name] or "cloudy"
end

local NIGHT_ICONS = {
    clear_day = "clear_night",
    mostly_sunny = "mostly_clear_night",
    partly_cloudy_day = "partly_cloudy_night",
    scattered_showers_day = "scattered_showers_night",
    scattered_snow_showers_day = "scattered_snow_showers_night",
    isolated_thunderstorms = "isolated_scattered_thunderstorms_night",
}

local function night_icon(day_icon)
    return NIGHT_ICONS[day_icon] or day_icon
end

local WIND_DIRS = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" }

local function wind_direction_label(degrees)
    if not degrees then return "?" end
    local index = math.floor((degrees + 11.25) / 22.5) % 16 + 1
    return WIND_DIRS[index]
end

local function convert_temp(v, temp_unit)
    if v == nil then return nil end
    if temp_unit == "fahrenheit" then
        return v * 9/5 + 32
    end
    return v
end

local function convert_wind(v, wind_unit)
    if v == nil then return nil end
    if wind_unit == "ms" then return v / 3.6
    elseif wind_unit == "mph" then return v / 1.609
    elseif wind_unit == "knots" then return v / 1.852
    else return v end
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
    for __, h in ipairs(hourly) do
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
    local total = #hourly
    if count <= 0 or total <= 0 then return nil end
    if count >= total and all_light then
        return string.format(_("%s will continue throughout the day"), "")
    elseif count >= total then
        return string.format(_("%s will continue throughout the day"), "")
    elseif last_time then
        if all_light then
            return string.format(_("%s will continue until %s"), "", last_time)
        else
            return string.format(_("%s will continue until %s"), "", last_time)
        end
    end
    return nil
end

function M.fetch(lat, lon, temp_unit, forecast_days, wind_unit, precip_unit)
    temp_unit = temp_unit or "celsius"
    forecast_days = forecast_days or 7
    wind_unit = wind_unit or "kmh"

    local api_key = config.get("weather_visualcrossing_key", "")
    if not api_key or api_key == "" then
        return nil, _("Visual Crossing API key not set")
    end

    local ok, http = pcall(require, "socket.http")
    if not ok then
        return nil, "HTTP module not available"
    end

    local url = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/"
        .. tostring(lat) .. "," .. tostring(lon)
        .. "?unitGroup=metric"
        .. "&include=current,hours,days"
        .. "&key=" .. api_key
        .. "&contentType=json"

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

    if data.errorCode or data.error then
        return nil, tostring(data.error or data.errorMessage or "API error")
    end

    local result = {}
    if data.resolvedAddress then
        result.location_name = data.resolvedAddress
    end

    -- Current conditions
    local current = data.currentConditions
    if not current then
        return nil, "No current conditions in response"
    end

    local icon_name = current.icon or "cloudy"
    local cond_text = current.conditions or "?"
    local is_night = icon_name:match("night$")
    local s4_icon = get_icon(icon_name)

    local wind_speed = convert_wind(current.windspeed, wind_unit)
    local t = convert_temp(current.temp, temp_unit)
    local feels = convert_temp(current.feelslike, temp_unit)
    local dew = convert_temp(current.dew, temp_unit)
    local hi = nil
    local wc = nil
    if t and t >= 26 then
        hi = t
    end
    if t and t <= 10 then
        wc = t
    end

    result.current = {
        temperature = t,
        apparent_temperature = feels,
        humidity = current.humidity,
        dew_point = dew,
        weather_code = WMO_MAP[icon_name] or 0,
        weather_text = cond_text,
        weather_icon = s4_icon,
        wind_speed = wind_speed,
        wind_direction = current.winddir,
        wind_label = wind_direction_label(current.winddir),
        pressure = current.pressure,
        heat_index = hi,
        wind_chill = wc,
        is_day = is_night and 0 or 1,
    }

    if t and t >= 30 then
        result.current.weather_icon = "very_hot"
        result.current.weather_text = _("Too hot")
    elseif t and t <= 0 then
        result.current.weather_icon = "very_cold"
        result.current.weather_text = _("Too cold")
    end

    -- Daily & hourly data
    result.daily = {}
    result.hourly = {}

    if not data.days or #data.days == 0 then
        return result, nil
    end

    local now_ts = os.time()
    local today_str = os.date("%Y-%m-%d")
    local weekdays = { _("Sun"), _("Mon"), _("Tue"), _("Wed"), _("Thu"), _("Fri"), _("Sat") }
    local english_weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

    local max_days = math.min(forecast_days, 15)

    for __, day in ipairs(data.days) do
        if #result.daily >= max_days then break end

        local date_str = day.datetime or ""
        if not date_str or date_str == "" then goto continue end
        if date_str < today_str then goto continue end

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
            day_label = weekday_num and weekdays[weekday_num] or english_weekdays[weekday_num] or date_str
        end

        local day_icon_name = day.icon or "cloudy"
        local day_s4_icon = get_icon(day_icon_name)
        local day_cond_text = day.conditions or "?"
        local day_wmo = WMO_MAP[day_icon_name] or 0

        local temp_max = convert_temp(day.tempmax, temp_unit)
        local temp_min = convert_temp(day.tempmin, temp_unit)

        local maxwind
        if day.windspeed then
            maxwind = convert_wind(day.windspeed, wind_unit)
        elseif day.windgust then
            maxwind = convert_wind(day.windgust, wind_unit)
        end

        table.insert(result.daily, {
            date = date_str,
            day_label = day_label,
            temp_max = temp_max,
            temp_min = temp_min,
            weather_code = day_wmo,
            weather_icon = day_s4_icon,
            weather_text = day_cond_text,
            precip_sum = day.precip or 0,
            precip_prob = day.precipprob or 0,
            uv_index = day.uvindex,
            wind_max = maxwind,
            sunrise = day.sunrise or "",
            sunset = day.sunset or "",
        })

        -- Hourly data from this day
        if day.hours and #day.hours > 0 then
            for __, h in ipairs(day.hours) do
                if #result.hourly >= 24 then break end

                local h_time_str = h.datetime or ""
                local h_hour, h_min = h_time_str:match("^(%d%d):(%d%d)")
                if not h_hour then goto continue_h end

                local hh = tonumber(h_hour)

                -- Skip hours before now for today
                if date_str == today_str then
                    local current_hour = os.date("*t", now_ts)
                    if hh < current_hour.hour then goto continue_h end
                end

                local h_icon_name = h.icon or "cloudy"
                local h_s4_icon = get_icon(h_icon_name)
                local h_cond_text = h.conditions or "?"
                local h_wmo = WMO_MAP[h_icon_name] or 0

                local is_night_h = h_icon_name:match("night$")
                if is_night_h then
                    h_s4_icon = night_icon(h_s4_icon)
                end

                local hour_label = string.format("%02d:00", hh)
                local h_temp = convert_temp(h.temp, temp_unit)
                local h_wind = convert_wind(h.windspeed, wind_unit)

                table.insert(result.hourly, {
                    time = hour_label,
                    temperature = h_temp,
                    humidity = h.humidity,
                    weather_code = h_wmo,
                    weather_icon = h_s4_icon,
                    weather_text = h_cond_text,
                    precip_prob = h.precipprob or 0,
                    precip = h.precip or 0,
                    wind_speed = h_wind,
                    wind_direction = h.winddir,
                    is_night = is_night_h,
                })
                ::continue_h::
            end
        end
        ::continue::
    end

    if result.current and result.hourly then
        result.current.precip_prediction, result.current.precip_is_snow = rain_prediction(result.hourly)
    end

    return result, nil
end

return M
