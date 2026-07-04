local io = require("io")

local config_file
local data = {}

local function getConfigFile()
    if config_file then return config_file end
    local src = debug.getinfo(1, "S")
    local dir = src and src.source:match("@(.*/)")
    if dir then
        config_file = dir .. "weather_settings.lua"
    else
        local DataStorage = require("datastorage")
        config_file = DataStorage:getDataDir() .. "/weather_settings.lua"
    end
    return config_file
end

local function loadFile()
    local path = getConfigFile()
    if not path then return end
    local f = io.open(path, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
        local ok, chunk = load(content, path)
        if ok then
            local ok2, result = pcall(chunk)
            if ok2 and type(result) == "table" then
                data = result
            end
        end
    end
end

local function serializeValue(v, indent)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local parts = {}
        local keys = {}
        for k in pairs(v) do table.insert(keys, k) end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return type(a) < type(b) end
            return a < b
        end)
        for __, k in ipairs(keys) do
            local vv = v[k]
            local k_str
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                k_str = k
            else
                k_str = "[" .. serializeValue(k, indent) .. "]"
            end
            parts[#parts + 1] = string.rep(" ", indent or 0) ..
                "    " .. k_str .. " = " .. serializeValue(vv, (indent or 0) + 4) .. ",\n"
        end
        return "{\n" .. table.concat(parts) .. string.rep(" ", indent or 0) .. "}"
    else
        return "nil"
    end
end

local function saveFile()
    local path = getConfigFile()
    if not path then return end
    local f = io.open(path, "w")
    if not f then return end
    f:write("-- Auto-generated config file, do not edit manually\n")
    f:write("return ")
    f:write(serializeValue(data, 0))
    f:write("\n")
    f:close()
end

loadFile()

local M = {}

function M.get(key, default)
    local v = data[key]
    if v == nil then return default end
    return v
end

function M.set(key, val)
    data[key] = val
    saveFile()
end

function M.toggle(key)
    data[key] = not data[key]
    saveFile()
end

function M.isTrue(key)
    return data[key] == true
end

function M.delete(key)
    data[key] = nil
    saveFile()
end

function M.setMany(t)
    for k, v in pairs(t) do
        data[k] = v
    end
    saveFile()
end

return M
