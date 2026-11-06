-- Run from the repository root with Lua 5.1.
local function noop() end
strmatch = string.match
securecallfunction = function (callback, ...) return callback(...) end
dofile("libs/LibStub/LibStub.lua")
dofile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local registry = LibStub("AceConfigRegistry-3.0")

local timers = {}
C_Timer = {After = function (_, callback) timers[#timers + 1] = callback end}
local function runTimers()
  local pending = timers
  timers = {}
  for _, callback in ipairs(pending) do callback() end
end
YES, NO = "Yes", "No"
StaticPopupDialogs = {}
local popup
StaticPopup_Show = function (which, text, _, data) popup = {which = which, text = text, data = data} end

-- Plain frames for the rows the translator draws itself.
local frames = {}
local function stubFrame()
  local frame = setmetatable({alpha = 1, scripts = {}}, {__index = function () return noop end})
  function frame:SetAlpha(alpha) self.alpha = alpha end
  function frame:GetFrameLevel() return 1 end
  function frame:GetWidth() return 600 end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:HookScript(name, callback) self.scripts[name] = callback end
  function frame:SetText(text) self.text = text end
  function frame:GetText() return self.text end
  function frame:GetStringHeight() return 20 end
  function frame:GetFont() return "font.ttf", 12, "" end
  function frame:CreateFontString() return stubFrame() end
  frames[#frames + 1] = frame
  return frame
end
CreateFrame = function () return stubFrame() end

-- EllesmereUI widgets record what they were asked to draw.
local rows = {}
local function widget(kind)
  return function (_, _, text, _, ...)
    local row = stubFrame()
    row.kind, row.label, row.args = kind, text, {...}
    rows[#rows + 1] = row
    return row, 50
  end
end
local widgets = {}
for _, kind in ipairs({"SectionHeader", "Toggle", "Slider", "Dropdown", "Checkbox", "ColorPicker", "Button"}) do
  widgets[kind] = widget(kind)
end
local spec, activeModule, refreshes = nil, nil, {}
EllesmereUI = {
  Widgets = widgets, CONTENT_PAD = 45,
  RegisterPlugin = function (id, value) assert(id == "Glassy"); spec = value; return true end,
  GetPluginModuleKey = function (_, key) return "plugin:Glassy:"..key end,
  GetActiveModule = function () return activeModule end,
  RefreshPage = function (_, force) refreshes[#refreshes + 1] = force and "force" or "fast" end,
  InvalidateModulePageCache = function (_, key) refreshes[#refreshes + 1] = "invalidate "..key end,
  IsSearchPrebuild = function () return false end,
}

-- A small options tree that uses every AceConfig feature Glassy's settings use.
local db = {enabled = true, size = 12, mode = "b", frames = {ChatFrame1 = true}, color = {0.1, 0.2, 0.3, 0.4}, text = "old"}
local profiles = {current = "Default"}
local handler = {
  GetProfile = function (_, info) assert(info.handler and info.arg == "common"); return profiles.current end,
  SetProfile = function (_, _, value) profiles.current = value end,
  List = function (_, info) assert(info.arg == "common"); return {Default = "Default", Raid = "Raid"} end,
}
local printed
local options = {
  type = "group", name = "Glassy",
  args = {
    general = {
      type = "group", name = "General", order = 1,
      args = {
        appearance = {
          type = "group", name = "Appearance", inline = true, order = 1,
          get = function (info) return db[info[#info]] end,
          set = function (info, value) db[info[#info]] = value end,
          args = {
            enabled = {type = "toggle", name = "Enabled", desc = "Turns it on", order = 1},
            size = {type = "range", name = "Size", order = 2, min = 1, max = 100, softMin = 6, softMax = 24, step = 1,
              disabled = function () return not db.enabled end},
            secret = {type = "toggle", name = "Hidden", order = 3, hidden = true},
            mode = {type = "select", name = "Mode", order = 4, values = {a = "Alpha", b = "Beta"}, sorting = {"b", "a"}},
            font = {type = "select", name = "Font", order = 5, dialogControl = "LSM30_Font",
              values = {Friz = "Fonts\\Friz.ttf"}, get = function () return "Friz" end, set = noop},
            last = {type = "description", name = "Last", order = -1},
          },
        },
        frames = {type = "multiselect", name = "Windows", order = 2, values = {ChatFrame1 = "General", ChatFrame3 = "Trade"},
          get = function (_, key) return db.frames[key] end, set = function (_, key, value) db.frames[key] = value end},
        color = {type = "color", name = "Color", order = 3, hasAlpha = true,
          get = function () return unpack(db.color) end, set = function (_, ...) db.color = {...} end},
        text = {type = "input", name = "Text", order = 4, get = function () return db.text end,
          set = function (_, value) db.text = value end,
          validate = function (_, value) return value ~= "bad" or "Rejected" end},
      },
    },
    profile = {
      type = "group", name = "Profiles", order = 2, handler = handler,
      args = {
        choose = {type = "select", name = "Profile", arg = "common", values = "List", get = "GetProfile", set = "SetProfile",
          confirm = function (_, value) return value == "Raid" and "Switch to Raid?" end},
        reset = {type = "execute", name = "Reset", order = 2, func = function () db.text = "reset" end, confirm = true,
          confirmText = "Really reset?"},
      },
    },
  },
}
registry:RegisterOptionsTable("Glassy", options)

local updateListeners = {}
local module = {}
local core = {
  Libs = {AceConfigRegistry = registry},
  defaults = {profile = {enabled = true, size = 12, color = {r = 1, g = 1, b = 1}, chatFadeInDuration = 0.4}},
  db = {RegisterCallback = noop, profile = {enabled = false, size = 30, color = {r = 0, g = 0, b = 0}}},
  GetModule = function (_, name) return name == "Config" and {Print = function (_, text) printed = text end} or module end,
  Subscribe = function (_, _, callback) updateListeners[#updateListeners + 1] = callback end,
}
assert(loadfile("Glassy/Modules/EllesmereOptions.lua"))("Glassy", {core, {EVENTS = {UPDATE_CONFIG = "update"}}})
module:OnEnable()

assert(spec.label == "Glassy" and #spec.modules == 2, "Each top-level settings group becomes a module")
assert(spec.modules[1].key == "general" and spec.modules[1].pages[1] == "General")
assert(spec.modules[2].title == "Glassy profiles", "Titles avoid EllesmereUI's reserved Profiles section")

-- EllesmereUI's Reset button restores the section's saved settings; sections without settings get none.
assert(spec.modules[2].onReset == nil, "Sections without settings have no Reset button")
spec.modules[1].onReset()
local profileValues = core.db.profile
assert(profileValues.enabled == true and profileValues.size == 12, "Reset restores the section's defaults")
assert(profileValues.color.r == 1 and profileValues.color ~= core.defaults.profile.color, "Table defaults are copied")
assert(profileValues.chatFadeInDuration == nil, "Settings of other sections stay untouched")

local function build(index)
  rows, frames = {}, {}
  local height = spec.modules[index].buildPage(spec.modules[index].pages[1], stubFrame(), -10)
  return height
end
local function row(label)
  for _, entry in ipairs(rows) do if entry.label == label then return entry end end
end

assert(build(1) > 0)
assert(row("Appearance").kind == "SectionHeader" and not row("Hidden"), "Inline groups become sections; hidden options are skipped")
local toggle = row("Enabled")
assert(toggle.args[1]() == true and toggle.args[3] == "Turns it on", "Inherited getters and tooltips are used")
local slider = row("Size")
assert(slider.args[1] == 6 and slider.args[2] == 24 and slider.args[3] == 1, "Sliders use the soft range")
assert(slider.alpha == 1, "Enabled rows are not dimmed")
local dropdown = row("Mode")
assert(dropdown.args[1].b == "Beta" and dropdown.args[4][1] == "b", "Dropdowns keep the option's sorting")
assert(row("Font").args[1].Friz == "Friz", "Font pickers list font names")
assert(row("Windows").kind == "SectionHeader" and row("General").kind == "Checkbox" and row("Trade"))
local color = row("Color")
local r, _, _, a = color.args[1]()
assert(r == 0.1 and a == 0.4 and color.args[3] == true)

-- Discrete changes notify AceConfig, which rebuilds this page for new disabled states.
activeModule = "plugin:Glassy:general"
toggle.args[2](false)
assert(db.enabled == false)
runTimers()
assert(refreshes[1] == "force" and refreshes[2] == "invalidate plugin:Glassy:profile",
  "A toggle rebuilds the visible page and drops the other cached pages")
build(1)
assert(row("Size").alpha < 1, "Disabled rows are dimmed")

-- EllesmereUI's search pre-build pass hands out stand-in frames, so no real frames may be created then.
local prebuild = true
EllesmereUI.IsSearchPrebuild = function () return prebuild end
local realCreateFrame = CreateFrame
CreateFrame = function () error("Real frame created during the search pass") end
build(1)
assert(row("Size") and row("Text") == nil, "The search pass indexes widgets without drawing custom rows")
CreateFrame, prebuild = realCreateFrame, false
build(1)

-- Continuous changes only re-read values in place.
row("Size").args[5](18)
runTimers()
assert(db.size == 18 and refreshes[#refreshes] == "fast", "Slider drags never rebuild the page")
row("Trade").args[2](true)
assert(db.frames.ChatFrame3 == true, "Multiselect checkboxes write their own key")

-- Text inputs validate before they are saved.
local input
for _, frame in ipairs(frames) do if frame.scripts.OnEnterPressed then input = frame end end
input.text = "bad"
input.scripts.OnEnterPressed(input)
assert(db.text == "old" and printed == "Rejected", "Invalid input is reported and not saved")
printed = nil
input.scripts.OnEditFocusLost(input)
assert(printed == nil, "Leaving the box does not report the same rejection twice")
local accept
for _, frame in ipairs(frames) do if frame.scripts.OnClick then accept = frame end end
input.text = "new"
input.scripts.OnTextChanged(input, true)
accept.scripts.OnClick(accept)
assert(db.text == "new", "Accept saves text without Enter, since other buttons never take its focus")

-- Handler method names, info.arg, and confirmations work like AceConfig.
build(2)
local profile = row("Profile")
assert(profile.args[2]() == "Default" and profile.args[1].Raid == "Raid")
profile.args[3]("Raid")
assert(profiles.current == "Default" and popup.text == "Switch to Raid?", "Confirmations wait for the player")
popup.data()
assert(profiles.current == "Raid")
row("Reset").args[1]()
assert(popup.text == "Really reset?")
popup.data()
assert(db.text == "reset")

-- Changes made elsewhere refresh the open page.
runTimers()
refreshes = {}
updateListeners[1]()
runTimers()
assert(refreshes[1] == "fast", "Glassy setting changes refresh the open page")
activeModule = nil
registry:NotifyChange("Glassy")
runTimers()
assert(refreshes[2] == "invalidate plugin:Glassy:general", "Hidden pages are rebuilt next time they open")
print("PASS: EllesmereUI settings mirror Glassy's AceConfig options with the same callbacks and states")
