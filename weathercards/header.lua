local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local ImageWidget = require("ui/widget/imagewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Block 1: Header Hero — current conditions + big temp + icon + feels like
return function(h)
    local self, data, cur, acw = h.self, h.data, h.cur, h.acw
    local hero = VerticalGroup:new { align = "left" }
    local r1_h = Screen:scaleBySize(20)
    local r2_h = Screen:scaleBySize(95)

    if not h.menu_ref then
        table.insert(hero, OverlapGroup:new {
            dimen = Geom:new { w = acw, h = r1_h },
            TextWidget:new {
                text = _("Now"),
                face = Font:getFace("smallinfofont", 16),
                fgcolor = Blitbuffer.COLOR_DIM_GRAY,
            },
        })
        table.insert(hero, VerticalSpan:new { width = Screen:scaleBySize(2) })
    end

    local big = HorizontalGroup:new { align = "center" }
    table.insert(big, TextWidget:new {
        text = string.format("%d", math.floor(cur.temperature + 0.5)),
        face = Font:getFace("pgfont", 60), bold = true,
    })
    table.insert(big, TextWidget:new {
        text = "°", face = Font:getFace("pgfont", 32), bold = true,
    })
    table.insert(big, ImageWidget:new {
        file = h.plugin_dir .. "resources/google-weather/set-4/" .. cur.weather_icon .. ".svg",
        width = Screen:scaleBySize(48), height = Screen:scaleBySize(48),
        alpha = true, is_icon = true,
    })

    local left_side = VerticalGroup:new { align = "left" }
    table.insert(left_side, big)
    if data.daily and data.daily[1] then
        local d1 = data.daily[1]
        local hi = d1.temp_max and string.format("%d°", math.floor(d1.temp_max + 0.5)) or "--"
        local lo = d1.temp_min and string.format("%d°", math.floor(d1.temp_min + 0.5)) or "--"
        table.insert(left_side, TextWidget:new {
            text = string.format("%s %s • %s %s", _("High:"), hi, _("Low:"), lo),
            face = Font:getFace("smallinfofont", 16),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
    end

    local rc = VerticalGroup:new { align = "right" }
    table.insert(rc, TextWidget:new {
        text = cur.weather_text, face = Font:getFace("infofont", 22), bold = true,
    })
    table.insert(rc, TextWidget:new {
        text = string.format("%s %d°", _("Feels like"), math.floor(cur.apparent_temperature + 0.5)),
        face = Font:getFace("smallinfofont", 18), fgcolor = Blitbuffer.COLOR_DIM_GRAY,
    })
    if cur.heat_index and cur.heat_index >= 30 then
        table.insert(rc, TextWidget:new {
            text = string.format("%s %d°", _("Heat Index"), math.floor(cur.heat_index + 0.5)),
            face = Font:getFace("smallinfofont", 16), fgcolor = h.gauges.rgb(220, 80, 80),
        })
    elseif cur.wind_chill and cur.wind_chill <= 0 then
        table.insert(rc, TextWidget:new {
            text = string.format("%s %d°", _("Wind Chill"), math.floor(cur.wind_chill + 0.5)),
            face = Font:getFace("smallinfofont", 16), fgcolor = h.gauges.rgb(80, 80, 220),
        })
    end

    -- Measure actual content height for correct OverlapGroup dimen
    local actual_h = math.max(r2_h,
        left_side:getSize() and left_side:getSize().h or 0,
        rc:getSize() and rc:getSize().h or 0)

    table.insert(hero, OverlapGroup:new {
        dimen = Geom:new { w = acw, h = actual_h },
        left_side,
        RightContainer:new {
            dimen = Geom:new { w = acw, h = actual_h },
            rc,
        },
    })
    if h.cached and h.cache_age then
        local mins = math.floor(h.cache_age / 60)
        local cached_text
        if mins < 60 then
            cached_text = string.format(_("Cached %d min ago"), mins)
        else
            cached_text = string.format(_("Cached %d hour ago"), math.floor(mins / 60))
        end
        table.insert(hero, TextWidget:new {
            text = cached_text,
            face = Font:getFace("smallinfofont", 14),
            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
        })
    end
    self:add(h.card(hero))
end
