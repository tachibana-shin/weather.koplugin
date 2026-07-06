local _ = require("weather_i18n")
local config = require("weather_config")

local M = {}

local TOMORROWIO_ICONS = {
    [1000] = "clear_day",
    [1100] = "mostly_sunny",
    [1101] = "partly_cloudy_day",
    [1102] = "mostly_cloudy_day",
    [1001] = "cloudy",
    [2000] = "haze_fog_dust_smoke",
    [2100] = "haze_fog_dust_smoke",
    [4000] = "drizzle",
    [4200] = "rain_with_cloudy",
    [4001] = "showers_rain",
    [4201] = "heavy_rain",
    [5001] = "flurries",
    [5100] = "cloudy_with_snow",
    [5000] = "snow_with_cloudy",
    [5101] = "heavy_snow",
    [6000] = "icy",
    [6200] = "icy",
    [6001] = "mixed_rain_snow",
    [6201] = "mixed_rain_snow",
    [7000] = "mixed_rain_hail_sleet",
    [7102] = "mixed_rain_hail_sleet",
    [7101] = "mixed_rain_hail_sleet",
    [8000] = "isolated_thunderstorms",
}

-- Composite codes (precipitation + sky condition combinations)
local COMPOSITE_ICONS = {
    [2101] = "haze_fog_dust_smoke", [2102] = "haze_fog_dust_smoke",
    [2103] = "haze_fog_dust_smoke", [2106] = "haze_fog_dust_smoke",
    [2107] = "haze_fog_dust_smoke", [2108] = "haze_fog_dust_smoke",
    [4203] = "drizzle", [4204] = "drizzle", [4205] = "drizzle",
    [4202] = "heavy_rain", [4211] = "heavy_rain", [4212] = "heavy_rain",
    [4208] = "showers_rain", [4209] = "showers_rain", [4210] = "showers_rain",
    [4213] = "rain_with_cloudy", [4214] = "rain_with_cloudy", [4215] = "rain_with_cloudy",
    [5115] = "flurries", [5116] = "flurries", [5117] = "flurries",
    [5122] = "cloudy_with_snow", [5121] = "cloudy_with_snow", [5120] = "cloudy_with_snow",
    [5102] = "snow_with_cloudy", [5105] = "snow_with_cloudy", [5108] = "snow_with_cloudy",
    [5107] = "heavy_snow", [5104] = "heavy_snow", [5101] = "heavy_snow",
}

local function get_icon(code)
    return TOMORROWIO_ICONS[code] or COMPOSITE_ICONS[code] or "cloudy"
end

-- Map Tomorrow.io codes to approximate WMO codes for rain_prediction
local WMO_MAP = {
    [4000] = 51,
    [4200] = 61,
    [4001] = 63,
    [4201] = 65,
    [5001] = 71,
    [5100] = 71,
    [5000] = 73,
    [5101] = 75,
    [6000] = 56,
    [6200] = 56,
    [6001] = 66,
    [6201] = 67,
    [7000] = 77,
    [7102] = 77,
    [7101] = 77,
    [8000] = 95,
}

-- Composite WMO mappings
local COMPOSITE_WMO = {
    [4203] = 51, [4204] = 51, [4205] = 51,
    [4213] = 61, [4214] = 61, [4215] = 61,
    [4208] = 63, [4209] = 63, [4210] = 63,
    [4202] = 65, [4211] = 65, [4212] = 65,
    [5122] = 71, [5121] = 71, [5120] = 71,
    [5102] = 73, [5105] = 73, [5108] = 73,
    [5107] = 75, [5104] = 75, [5101] = 75,
}

local function get_wmo(code)
    return WMO_MAP[code] or COMPOSITE_WMO[code]
end

local CODES_TEXT = {
    [1000] = _("Clear sky"),
    [1100] = _("Mainly clear"),
    [1101] = _("Partly cloudy"),
    [1102] = _("Mostly cloudy"),
    [1001] = _("Overcast"),
    [2000] = _("Foggy"),
    [2100] = _("Light fog"),
    [4000] = _("Drizzle"),
    [4200] = _("Light rain"),
    [4001] = _("Moderate rain"),
    [4201] = _("Heavy rain"),
    [5001] = _("Flurries"),
    [5100] = _("Light snow"),
    [5000] = _("Moderate snow"),
    [5101] = _("Heavy snow"),
    [6000] = _("Light freezing drizzle"),
    [6200] = _("Light freezing rain"),
    [6001] = _("Freezing rain"),
    [6201] = _("Heavy freezing rain"),
    [7000] = _("Ice pellets"),
    [7102] = _("Light ice pellets"),
    [7101] = _("Heavy ice pellets"),
    [8000] = _("Thunderstorm"),
}

local function get_text(code)
    return CODES_TEXT[code] or "?"
end

local NIGHT_ICON_MAP = {
    clear_day = "clear_night",
    mostly_sunny = "mostly_clear_night",
    mostly_cloudy_day = "mostly_cloudy_night",
    partly_cloudy_day = "partly_cloudy_night",
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

local function parse_iso_time(iso_str)
    if not iso_str then return nil end
    local parts = {}
    for part in iso_str:gmatch("[%d]+") do
        table.insert(parts, tonumber(part))
    end
    if #parts >= 4 then
        return os.time { year = parts[1], month = parts[2], day = parts[3], hour = parts[4] }
    end
    return nil
end

local function extract_hour(iso_str)
    if not iso_str then return nil end
    local parts = {}
    for part in iso_str:gmatch("[%d]+") do
        table.insert(parts, tonumber(part))
    end
    return parts[4]
end

local function extract_date(iso_str)
    if not iso_str then return "" end
    return iso_str:match("^(%d+-%d+-%d+)") or ""
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
    if wind_unit == "ms" then return v
    elseif wind_unit == "mph" then return v * 2.237
    elseif wind_unit == "knots" then return v * 1.944
    else return v * 3.6 end
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

function M.fetch(lat, lon, temp_unit, forecast_days, wind_unit)
    temp_unit = temp_unit or "celsius"
    forecast_days = forecast_days or 7
    wind_unit = wind_unit or "kmh"

    local api_key = config.get("weather_tomorrowio_key", "")
    if not api_key or api_key == "" then
        return nil, _("Tomorrow.io API key not set")
    end

    local ok, http = pcall(require, "socket.http")
    if not ok then
        return nil, "HTTP module not available"
    end

    local days = math.min(forecast_days, 5)

    local url = "https://api.tomorrow.io/v4/weather/forecast"
        .. "?location=" .. tostring(lat) .. "," .. tostring(lon)
        .. "&timesteps=1h&timesteps=1d"
        .. "&units=metric"
        .. "&apikey=" .. api_key

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

    if data.code and data.code ~= 200001 then
        if data.type and data.type == "Fatal" then
            return nil, data.message or "API error"
        end
    end

    local result = {}

    -- Forecast endpoint returns timelines as object: { hourly: [...], daily: [...] }
    -- Timelines endpoint returns data.data.timelines as array
    -- Handle both formats
    local tl
    if data.data and data.data.timelines then
        local raw = data.data.timelines
        if type(raw) == "table" then
            -- Array format (Timelines POST endpoint)
            tl = {}
            for _, t in ipairs(raw) do
                if t.timestep == "1h" then tl.hourly = t.intervals
                elseif t.timestep == "1d" then tl.daily = t.intervals end
            end
        else
            tl = raw
        end
    elseif data.timelines then
        tl = data.timelines
    else
        return nil, "No timelines in response"
    end

    local hourly_intervals = tl.hourly
    local daily_intervals = tl.daily

    if not hourly_intervals or #hourly_intervals == 0 then
        return nil, "No hourly data in response"
    end

    local now_ts = os.time()

    -- Sort hourly intervals to ensure chronological order
    local sorted_hourly = {}
    for _, iv in ipairs(hourly_intervals) do
        local ts = parse_iso_time(iv.startTime or iv.time)
        if ts then
            table.insert(sorted_hourly, { iv = iv, ts = ts })
        end
    end
    table.sort(sorted_hourly, function(a, b) return a.ts < b.ts end)

    -- Find current interval (closest to now)
    local current_idx = 1
    for i, entry in ipairs(sorted_hourly) do
        if entry.ts >= now_ts then
            current_idx = i
            break
        end
    end

    -- Use the interval closest to now as current
    local current_entry = sorted_hourly[current_idx]
    if not current_entry then
        current_entry = sorted_hourly[#sorted_hourly]
    end
    if not current_entry then
        return nil, "No current weather data"
    end

    local cv = current_entry.iv.values
    local current_hour = extract_hour(current_entry.iv.startTime or current_entry.iv.time)
    local is_day = (current_hour and current_hour >= 6 and current_hour < 18) and 1 or 0

    local weather_code = cv.weatherCode or 0
    local icon_name = get_icon(weather_code)
    if is_day == 0 then
        icon_name = night_icon(icon_name)
    end

    local wind_speed = convert_wind(cv.windSpeed, wind_unit)

    local t = convert_temp(cv.temperature, temp_unit)
    local feels = convert_temp(cv.temperatureApparent, temp_unit)
    local dew = convert_temp(cv.dewPoint, temp_unit)

    result.current = {
        temperature = t,
        apparent_temperature = feels,
        humidity = cv.humidity,
        dew_point = dew,
        weather_code = weather_code,
        weather_text = get_text(weather_code),
        weather_icon = icon_name,
        wind_speed = wind_speed,
        wind_direction = cv.windDirection,
        wind_label = wind_direction_label(cv.windDirection),
        pressure = cv.pressureSurfaceLevel or cv.pressureSeaLevel,
        heat_index = nil,
        wind_chill = nil,
        is_day = is_day,
    }

    if t and t >= 30 then
        result.current.weather_icon = "very_hot"
        result.current.weather_text = _("Too hot")
    elseif t and t <= 0 then
        result.current.weather_icon = "very_cold"
        result.current.weather_text = _("Too cold")
    end

    -- Hourly data (from current time onward)
    result.hourly = {}
    for i = current_idx, #sorted_hourly do
        local entry = sorted_hourly[i]
        local vals = entry.iv.values
        local iv_time = entry.iv.startTime or entry.iv.time

        local h_code = vals.weatherCode or 0
        local h_icon = get_icon(h_code)
        local h_hour = extract_hour(iv_time)
        local is_night_hour = h_hour and (h_hour < 6 or h_hour >= 18)
        if is_night_hour then
            h_icon = night_icon(h_icon)
        end

        local hour_str = h_hour and string.format("%02d:00", h_hour) or "??:00"
        local h_temp = convert_temp(vals.temperature, temp_unit)
        local h_wind = convert_wind(vals.windSpeed, wind_unit)

        table.insert(result.hourly, {
            time = hour_str,
            temperature = h_temp,
            humidity = vals.humidity,
            weather_code = h_code,
            weather_icon = h_icon,
            weather_text = get_text(h_code),
            precip_prob = vals.precipitationProbability or 0,
            precip = vals.rainIntensity or vals.precipitationIntensity or 0,
            wind_speed = h_wind,
            wind_direction = vals.windDirection,
            is_night = is_night_hour,
        })
        if #result.hourly >= 24 then break end
    end

    -- Map weather codes for rain_prediction
    if result.current and result.hourly then
        for _, h in ipairs(result.hourly) do
            local wmo = get_wmo(h.weather_code)
            if wmo then
                h.weather_code = wmo
            end
        end
        result.current.precip_prediction, result.current.precip_is_snow = rain_prediction(result.hourly)
    end

    -- Build hourly data grouped by date for daily aggregation
    local hourly_by_date = {}
    for _, entry in ipairs(sorted_hourly) do
        local iv_time = entry.iv.startTime or entry.iv.time
        local date_str = extract_date(iv_time)
        if not hourly_by_date[date_str] then
            hourly_by_date[date_str] = {}
        end
        table.insert(hourly_by_date[date_str], entry.iv.values)
    end

    -- Daily data
    if daily_intervals and #daily_intervals > 0 then
        local today_str = os.date("%Y-%m-%d")
        local weekdays = { _("Sun"), _("Mon"), _("Tue"), _("Wed"), _("Thu"), _("Fri"), _("Sat") }
        local english_weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

        -- Sort daily intervals chronologically, skip past dates
        local sorted_daily = {}
        for _, iv in ipairs(daily_intervals) do
            local iv_time = iv.startTime or iv.time
            local date_str = extract_date(iv_time)
            if date_str >= today_str then
                local ts = parse_iso_time(iv_time)
                if ts then
                    table.insert(sorted_daily, { iv = iv, ts = ts, date = date_str })
                end
            end
        end
        table.sort(sorted_daily, function(a, b) return a.ts < b.ts end)

        result.daily = {}
        for idx, entry in ipairs(sorted_daily) do
            if idx > days then break end
            local iv = entry.iv
            local vals = iv.values
            local iv_time = iv.startTime or iv.time
            local date_str = entry.date
            local parts = {}
            for part in (iv_time or ""):gmatch("[%d]+") do
                table.insert(parts, tonumber(part))
            end

            -- Aggregate weather code from hourly data for this date
            local day_hours = hourly_by_date[date_str]
            local d_code = vals.weatherCode or vals.weatherCodeFullDay
            local max_precip_prob = vals.precipitationProbability or vals.precipitationProbabilityAvg or 0
            local total_precip = vals.precipitationAccumulation or vals.rainAccumulation or vals.precipitationSum or 0
            if day_hours and #day_hours > 0 then
                if not d_code then
                    -- Use most common weather code from hourly data
                    local freq = {}
                    for _, hv in ipairs(day_hours) do
                        local wc = hv.weatherCode
                        if wc then
                            freq[wc] = (freq[wc] or 0) + 1
                        end
                    end
                    local max_freq = 0
                    for wc, count in pairs(freq) do
                        if count > max_freq then
                            max_freq = count
                            d_code = wc
                        end
                    end
                end
                if max_precip_prob == 0 then
                    for _, hv in ipairs(day_hours) do
                        local pp = hv.precipitationProbability or 0
                        if pp > max_precip_prob then max_precip_prob = pp end
                    end
                end
                if total_precip == 0 then
                    for _, hv in ipairs(day_hours) do
                        total_precip = total_precip + (hv.rainAccumulation or 0) + (hv.snowAccumulation or 0)
                    end
                end
            end
            d_code = d_code or 0
            local d_icon = get_icon(d_code)

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

            local temp_max = convert_temp(vals.temperatureMax or vals.temperature, temp_unit)
            local temp_min = convert_temp(vals.temperatureMin or vals.temperature, temp_unit)
            local maxwind = convert_wind(vals.windSpeedMax or vals.windSpeed, wind_unit)

            table.insert(result.daily, {
                date = date_str,
                day_label = day_label,
                temp_max = temp_max,
                temp_min = temp_min,
                weather_code = d_code,
                weather_icon = d_icon,
                weather_text = get_text(d_code),
                precip_sum = total_precip,
                precip_prob = max_precip_prob,
                uv_index = vals.uvIndexMax or vals.uvIndex,
                wind_max = maxwind,
                sunrise = vals.sunriseTime or "",
                sunset = vals.sunsetTime or "",
            })
        end
    end

    return result, nil
end

return M
