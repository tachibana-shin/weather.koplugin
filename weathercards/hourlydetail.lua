local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local _ = require("weather_i18n")

local Screen = Device.screen

-- Block 6: Hourly Details — tabbed rain/wind/humidity bar charts
return function(h)
    local self, data, acw = h.self, h.data, h.acw
    if not (data.hourly and #data.hourly > 0) then return end

    local mh = math.min(#data.hourly, 12)
    local tab_h = Screen:scaleBySize(30)
    local tw = math.floor(acw / 3)
    local body = VerticalGroup:new { align = "left" }
    local hourly_sel = 1

    local TabItem = InputContainer:extend {
        text = "",
        idx = 0,
        callback = nil,
    }
    function TabItem:init()
        local sel = self.idx == hourly_sel
        local bg = sel and h.gauges.rgb(66, 133, 244) or h.gauges.rgb(240, 240, 240)
        local fg = sel and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK
        self[1] = FrameContainer:new {
            dimen = Geom:new { w = tw, h = tab_h },
            background = bg, radius = Screen:scaleBySize(6),
            bordersize = 0, padding = 0,
            CenterContainer:new {
                dimen = Geom:new { w = tw, h = tab_h },
                TextWidget:new { text = self.text,
                    face = Font:getFace("smallinfofont", 15), fgcolor = fg },
            },
        }
        self.dimen = Geom:new { w = tw, h = tab_h }
        self.ges_events = {
            TapTab = {
                GestureRange:new {
                    ges = "tap",
                    range = function() return self.dimen end,
                },
            },
        }
    end

    function TabItem:onTapTab()
        if self.callback then
            self.callback(self)
        end
        return true
    end

    local function rebuildHourlyContent()
        while #body > 0 do
            body[#body] = nil
        end

        local tab_labels = { _("Rain"), _("Wind"), _("Humidity") }
        local tabs = HorizontalGroup:new { align = "center" }
        for i = 1, 3 do
            table.insert(tabs, TabItem:new {
                text = tab_labels[i],
                idx = i,
                callback = function(tab)
                    if tab.idx ~= hourly_sel then
                        hourly_sel = tab.idx
                        rebuildHourlyContent()
                        UIManager:setDirty(self, function()
                            return "ui", self.dimen
                        end)
                    end
                end,
            })
        end

        table.insert(body, tabs)
        table.insert(body, VerticalSpan:new { width = Screen:scaleBySize(8) })

        local BarPill = Widget:extend {
            w = 0, h = 0, bh = 0, color = nil,
        }
        function BarPill:getSize() return { w = self.w, h = self.h } end

        function BarPill:paintTo(bb, x, y)
            local top = math.floor(y + self.h - self.bh)
            bb:paintRect(math.floor(x), top, math.floor(self.w), math.floor(self.bh), self.color)
        end

        local function buildBars(getter, getcolor, maxval, precip_getter)
            local spacing = Screen:scaleBySize(4)
            local bw = math.floor((acw - spacing * (mh - 1)) / mh)
            local mhb = Screen:scaleBySize(60)
            local th = Screen:scaleBySize(18)
            local col_h = th + mhb + th + (precip_getter and th or 0)
            local bg = HorizontalGroup:new { align = "bottom" }
            for i = 1, mh do
                if i > 1 then
                    table.insert(bg, HorizontalSpan:new { width = spacing })
                end
                local h2 = data.hourly[i]
                local val = getter(h2)
                local ratio = maxval > 0 and math.min(val / maxval, 1) or 0
                local bh = math.max(2, math.floor(ratio * mhb))
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
                local col = VerticalGroup:new { align = "center",
                    CenterContainer:new {
                        dimen = Geom:new { w = bw, h = th },
                        TextWidget:new {
                            text = val > 0 and string.format("%d%%", math.floor(val + 0.5)) or "",
                            face = Font:getFace("smallinfofont", 15),
                            fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                            bold = true,
                        },
                    },
                }
                if precip_getter then
                    local amt = precip_getter(h2) or 0
                    table.insert(col, CenterContainer:new {
                        dimen = Geom:new { w = bw, h = th },
                        TextWidget:new {
                            text = amt > 0 and string.format("~%.1f", amt) or "",
                            face = Font:getFace("smallinfofont", 13),
                            bold = true,
                        },
                    })
                end
                table.insert(col, CenterContainer:new {
                    dimen = Geom:new { w = bw, h = mhb },
                    BarPill:new {
                        w = bw, h = mhb, bh = bh, color = getcolor(ratio),
                    },
                })
                table.insert(col, CenterContainer:new {
                    dimen = Geom:new { w = bw, h = th },
                    TextWidget:new {
                        text = tl, face = Font:getFace("smallinfofont", 15),
                        fgcolor = Blitbuffer.COLOR_DIM_GRAY,
                    },
                })
                table.insert(bg, CenterContainer:new {
                    dimen = Geom:new { w = bw, h = col_h },
                    col,
                })
            end
            return bg
        end

        if hourly_sel == 1 then
            local tp_prob = 0
            local tp_actual = 0
            for _, h2 in ipairs(data.hourly) do
                if h2.precip_prob then tp_prob = tp_prob + (h2.precip_prob / 100) end
                if h2.precip then tp_actual = tp_actual + h2.precip end
            end
            tp_prob = math.min(tp_prob, 99)
            table.insert(body, TextWidget:new {
                text = _("Today's rainfall"),
                face = Font:getFace("smallinfofont", 15),
                fgcolor = h.gauges.rgb(66, 133, 244),
            })
            table.insert(body, TextWidget:new {
                text = string.format("%.1f mm", tp_prob),
                face = Font:getFace("pgfont", 40), bold = true,
            })
            table.insert(body, TextWidget:new {
                text = string.format("%s: %.1f mm", _("Forecast rainfall"), tp_actual),
                face = Font:getFace("smallinfofont", 14),
                fgcolor = Blitbuffer.COLOR_DIM_GRAY,
            })
            table.insert(body, VerticalSpan:new { width = Screen:scaleBySize(8) })
            table.insert(body, buildBars(
                function(h2) return h2.precip_prob or 0 end,
                function(r)
                    if r > 0.5 then
                        return h.gauges.rgb(30, 100, 220)
                    elseif r > 0.2 then
                        return h.gauges.rgb(66, 133, 244)
                    else
                        return h.gauges.rgb(150, 190, 240)
                    end
                end,
                100,
                function(h2) return h2.precip or 0 end
            ))
        elseif hourly_sel == 2 then
            local tws = 0
            for _, h2 in ipairs(data.hourly) do
                tws = tws + (h2.wind_speed or 0)
            end
            local avg = #data.hourly > 0 and math.floor(tws / #data.hourly + 0.5) or 0
            table.insert(body, TextWidget:new {
                text = _("Average wind speed"),
                face = Font:getFace("smallinfofont", 15),
                fgcolor = h.gauges.rgb(66, 133, 244),
            })
            table.insert(body, TextWidget:new {
                text = string.format("%d km/h", avg),
                face = Font:getFace("pgfont", 40), bold = true,
            })
            table.insert(body, VerticalSpan:new { width = Screen:scaleBySize(8) })
            table.insert(body, buildBars(
                function(h2) return h2.wind_speed or 0 end,
                function(_) return h.gauges.rgb(66, 133, 244) end,
                30
            ))
        elseif hourly_sel == 3 then
            local th = 0
            for _, h2 in ipairs(data.hourly) do
                th = th + (h2.humidity or 0)
            end
            local avg = #data.hourly > 0 and math.floor(th / #data.hourly + 0.5) or 0
            table.insert(body, TextWidget:new {
                text = _("Average humidity"),
                face = Font:getFace("smallinfofont", 15),
                fgcolor = h.gauges.rgb(66, 133, 244),
            })
            table.insert(body, TextWidget:new {
                text = string.format("%d%%", avg),
                face = Font:getFace("pgfont", 40), bold = true,
            })
            table.insert(body, VerticalSpan:new { width = Screen:scaleBySize(8) })
            table.insert(body, buildBars(
                function(h2) return h2.humidity or 0 end,
                function(_) return h.gauges.rgb(66, 133, 244) end,
                100
            ))
        end
    end

    rebuildHourlyContent()

    self:add(h.card(VerticalGroup:new {
        align = "left",
        TextWidget:new {
            text = _("Hourly Details"),
            face = Font:getFace("infofont", 22), bold = true,
        },
        VerticalSpan:new { width = Screen:scaleBySize(4) },
        body,
    }))
end
