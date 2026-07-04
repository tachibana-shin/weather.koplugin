local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local ImageWidget = require("ui/widget/imagewidget")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Block 2: Hourly Forecast — scrollable 24h preview
return function(h)
    local self, data, acw = h.self, h.data, h.acw
    if not (data.hourly and #data.hourly > 0) then return end

    local mh = math.min(#data.hourly, 24)
    local cw2 = Screen:scaleBySize(54)
    local hc_h = Screen:scaleBySize(120)
    local sc_h = hc_h + 3 * Screen:scaleBySize(3)
    local title = TextWidget:new {
        text = _("Hourly Forecast"),
        face = Font:getFace("infofont", 22), bold = true,
    }
    local hg = HorizontalGroup:new { align = "center" }
    for i = 1, mh do
        local h2 = data.hourly[i]
        local col = VerticalGroup:new { align = "center" }
        table.insert(col, TextWidget:new {
            text = h2.temperature and string.format("%d°", math.floor(h2.temperature + 0.5)) or "--",
            face = Font:getFace("infofont", 17), bold = true,
        })
        table.insert(col, TextWidget:new {
            text = h2.precip_prob and string.format("%d%%", h2.precip_prob) or "",
            face = Font:getFace("smallinfofont", 16),
            fgcolor = h.gauges.rgb(66, 133, 244),
        })
        table.insert(col, CenterContainer:new {
            dimen = Geom:new { w = Screen:scaleBySize(28), h = Screen:scaleBySize(28) },
            ImageWidget:new {
                file = h.plugin_dir .. "resources/google-weather/set-4/" .. (h2.weather_icon or "cloudy") .. ".svg",
                width = Screen:scaleBySize(24), height = Screen:scaleBySize(24),
                alpha = true, is_icon = true,
            },
        })
        local tl
        if i == 1 then
            tl = _("Now")
        else
            local hr = tonumber(h2.time:match("^(%d+)")) or 0
            if hr == 0 then
                tl = "12" .. _("AM")
            elseif hr < 12 then
                tl = tostring(hr) .. _("AM")
            elseif hr == 12 then
                tl = "12" .. _("PM")
            else
                tl = tostring(hr - 12) .. _("PM")
            end
        end
        table.insert(col, TextWidget:new {
            text = tl, face = Font:getFace("smallinfofont", 15),
            fgcolor = i == 1 and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_DIM_GRAY,
        })
        table.insert(hg, CenterContainer:new {
            dimen = Geom:new { w = cw2, h = hc_h },
            col,
        })
    end
    local tw = mh * cw2
    local sc = ScrollableContainer:new {
        dimen = Geom:new { w = acw, h = sc_h },
        scroll_bar_width = Screen:scaleBySize(3),
        swipe_full_view = false,
    }
    sc.show_parent = self
    sc[1] = FrameContainer:new {
        width = tw, bordersize = 0, padding = 0, hg,
    }
    self:add(h.card(VerticalGroup:new {
        align = "left",
        title,
        VerticalSpan:new { width = Screen:scaleBySize(4) },
        sc,
    }))
end
