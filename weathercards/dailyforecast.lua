local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("weather_i18n")

local Screen = Device.screen

local function dateLabel(d)
    if not d.date then return "" end
    local y, m, day = d.date:match("(%d+)-(%d+)-(%d+)")
    if y then return string.format("%02d/%02d", day, m) end
    return ""
end

-- Block 3: 10-Day Forecast — daily temps with precipitation bars
return function(h)
    local self, data, acw = h.self, h.data, h.acw
    if not (data.daily and #data.daily > 0) then return end

    local sbw = h.menu_ref and Screen:scaleBySize(3) or 0
    local cw = acw - 3 * sbw  -- account for scrollbar width in Zen UI
    local md = math.min(#data.daily, 10)
    local c1 = cw * 0.18
    local c2 = cw * 0.18
    local c3 = cw * 0.22
    local c4 = cw * 0.42
    local gmin, gmax = math.huge, -math.huge
    for i = 1, md do
        local d = data.daily[i]
        if d.temp_min and d.temp_min < gmin then gmin = d.temp_min end
        if d.temp_max and d.temp_max > gmax then gmax = d.temp_max end
    end
    local grange = gmax - gmin
    if grange == 0 then grange = 1 end
    local rows = VerticalGroup:new { align = "left" }
    for i = 1, md do
        local d = data.daily[i]
        local row = HorizontalGroup:new { align = "center" }
        local day_content
        if i == 1 then
            day_content = TextWidget:new {
                text = _("Today"),
                face = Font:getFace("infofont", 17), bold = true,
            }
        else
            day_content = HorizontalGroup:new { align = "center",
                TextWidget:new {
                    text = d.day_label or "",
                    face = Font:getFace("infofont", 17), bold = true,
                },
                TextWidget:new {
                    text = " (" .. dateLabel(d) .. ")",
                    face = Font:getFace("infofont", 17),
                    fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                },
            }
        end
        table.insert(row, OverlapGroup:new {
            dimen = Geom:new { w = c1, h = Screen:scaleBySize(30) },
            day_content,
        })
        local ri = HorizontalGroup:new { align = "center" }
        if d.precip_prob and d.precip_prob > 0 then
            table.insert(ri, TextWidget:new {
                text = string.format("%d%%", d.precip_prob),
                face = Font:getFace("smallinfofont", 16),
                fgcolor = h.gauges.rgb(66, 133, 244),
            })
            table.insert(ri, HorizontalSpan:new { width = Screen:scaleBySize(2) })
        end
        table.insert(ri, ImageWidget:new {
            file = h.plugin_dir .. "resources/google-weather/set-4/" .. (d.weather_icon or "cloudy") .. ".svg",
            width = Screen:scaleBySize(22), height = Screen:scaleBySize(22),
            alpha = true, is_icon = true,
        })
        table.insert(row, CenterContainer:new {
            dimen = Geom:new { w = c2, h = Screen:scaleBySize(30) },
            ri,
        })
        local hi = d.temp_max and string.format("%d°", math.floor(d.temp_max + 0.5)) or "--"
        local lo = d.temp_min and string.format("%d°", math.floor(d.temp_min + 0.5)) or "--"
        table.insert(row, CenterContainer:new {
            dimen = Geom:new { w = c3, h = Screen:scaleBySize(30) },
            TextWidget:new {
                text = string.format("%s/%s", hi, lo),
                face = Font:getFace("infofont", 17),
            },
        })
        local bar_h = Screen:scaleBySize(12)
        local ts = ((d.temp_min or gmin) - gmin) / grange
        local te = ((d.temp_max or gmax) - gmin) / grange
        local bx = math.floor(c4 * ts)
        local bw = math.max(Screen:scaleBySize(3), math.floor(c4 * (te - ts)))
        table.insert(row, CenterContainer:new {
            dimen = Geom:new { w = c4, h = Screen:scaleBySize(30) },
            OverlapGroup:new {
                dimen = Geom:new { w = c4, h = bar_h },
                FrameContainer:new {
                    width = c4, height = bar_h,
                    bordersize = 0, padding = 0,
                    background = h.gauges.rgb(230, 230, 230),
                    HorizontalGroup:new { align = "center" },
                },
                FrameContainer:new {
                    width = bw, height = bar_h,
                    bordersize = 0, padding = 0,
                    background = h.gauges.rgb(66, 133, 244),
                    overlap_offset = { bx, 0 },
                    HorizontalGroup:new { align = "center" },
                },
            },
        })
        table.insert(rows, row)
        if i < md then
            table.insert(rows, VerticalSpan:new { width = Screen:scaleBySize(4) })
            table.insert(rows, LineWidget:new {
                dimen = Geom:new { w = cw, h = 1 },
                background = h.gauges.rgb(230, 230, 230), style = "solid",
            })
            table.insert(rows, VerticalSpan:new { width = Screen:scaleBySize(4) })
        end
    end
    local list = VerticalGroup:new { align = "left" }
    table.insert(list, TextWidget:new {
        text = _("10-Day Forecast"),
        face = Font:getFace("infofont", 22), bold = true,
    })
    table.insert(list, VerticalSpan:new { width = Screen:scaleBySize(6) })
    if h.menu_ref then
        -- Zen UI home widget: scrollable with fixed height
        local sc = ScrollableContainer:new {
            dimen = Geom:new { w = acw, h = Screen:scaleBySize(220) },
            scroll_bar_width = sbw,
            swipe_full_view = false,
        }
        sc.show_parent = h.menu_ref
        sc[1] = rows
        if sc.initState then sc:initState() end
        table.insert(list, sc)
    else
        -- WeatherView: full height, no scroll needed
        table.insert(list, rows)
    end
    self:add(h.card(list))
end
