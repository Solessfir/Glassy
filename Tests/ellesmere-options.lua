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
  function frame:GetWidth() return rawget(self, "width") or 600 end
  function frame:SetWidth(width) self.width = width end
  function frame:SetHeight(height) self.height = height end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:SetPoint(...)
    self.points = rawget(self, "points") or {}
    self.points[#self.points + 1] = {...}
  end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:HookScript(name, callback) self.scripts[name] = callback end
  function frame:SetText(text) self.text = text end
  function frame:GetText() return self.text end
  function frame:GetStringHeight() return 20 end
  function frame:SetFont(path, size, flags) self.font = {path, size, flags} end
  function frame:GetFont() return unpack(rawget(self, "font") or {"font.ttf", 12, ""}) end
  function frame:SetTextColor(...) self.textColor = {...} end
  function frame:SetColorTexture(...) self.textureColor = {...} end
  function frame:CreateFontString() return stubFrame() end
  function frame:CreateTexture() return stubFrame() end
  frames[#frames + 1] = frame
  return frame
end
CreateFrame = function (kind, _, parent, template)
  local frame = stubFrame()
  frame.frameType, frame.parent, frame.template = kind, parent, template
  return frame
end

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
local shownTooltip
EllesmereUI = {
  Widgets = widgets, CONTENT_PAD = 45,
  EXPRESSWAY = "house-font.ttf", TEXT_WHITE = {r = 1, g = 1, b = 1}, TEXT_DIM = {r = 1, g = 1, b = 1, a = 0.53},
  ELLESMERE_GREEN = {r = 0.1, g = 0.8, b = 0.6}, RB_COLOURS = {},
  ShowWidgetTooltip = function (_, text) shownTooltip = text end,
  HideWidgetTooltip = function () shownTooltip = nil end,
  RegisterPlugin = function (id, value) assert(id == "Glassy"); spec = value; return true end,
  GetPluginModuleKey = function (_, key) return "plugin:Glassy:"..key end,
  GetActiveModule = function () return activeModule end,
  RefreshPage = function (_, force) refreshes[#refreshes + 1] = force and "force" or "fast" end,
  InvalidateModulePageCache = function (_, key) refreshes[#refreshes + 1] = "invalidate "..key end,
  IsSearchPrebuild = function () return false end,
}
function EllesmereUI.MakeFont(parent, size, flags, ...)
  local label = parent:CreateFontString()
  label:SetFont(EllesmereUI.EXPRESSWAY, size, flags or "")
  label:SetTextColor(...)
  label.nativeFont = true
  return label
end
function EllesmereUI.MakeStyledButton(button, text, size, colors)
  assert(colors == EllesmereUI.RB_COLOURS)
  button.nativeButton = true
  button.label = EllesmereUI.MakeFont(button, size, nil, 1, 1, 1, 1)
  button.label:SetText(text)
end
function EllesmereUI.RowBg(frame, parent)
  assert(frame.parent == parent, "Native row colors are scoped to the page")
  frame.nativeRow = true
end
function EllesmereUI.MakeRoundedBorder(frame, r, g, b, a, background)
  frame.nativeBorder = {r, g, b, a}
  frame.background = background
end

-- A small options tree that uses every AceConfig feature Glassy's settings use.
NORMAL_FONT_COLOR_CODE = "|cffffd200"
local db = {enabled = true, size = 12, mode = "b", alias = "", frames = {ChatFrame1 = true}, color = {0.1, 0.2, 0.3, 0.4}, text = "old"}
local profiles = {current = "Default", available = {Default = "Default", Raid = "Raid"}}
local handler = {
  GetProfile = function (_, info) assert(info.handler and info.arg == "common" and info[0] == "Glassy" and info.uiName == "AceConfigDialog-3.0"); return profiles.current end,
  SetProfile = function (_, _, value) profiles.current = value; profiles.available[value] = value end,
  List = function (_, info) assert(info.arg == "common"); return profiles.available end,
  CopyProfile = function (_, _, value) profiles.copied = value end,
}
local printed
local options = {
  type = "group", name = "Glassy",
  args = {
    general = {
      type = "group", name = "General", order = 1,
      args = {
        appearance = {
          type = "group", name = "Appearance", desc = "Appearance settings", inline = true, order = 1,
          get = function (info) return db[info[#info]] end,
          set = function (info, value) db[info[#info]] = value end,
          args = {
            enabled = {type = "toggle", name = "Enabled", desc = "Turns it on", order = 1},
            size = {type = "range", name = "Size", order = 2, min = 1, max = 100, softMin = 6, softMax = 24, step = 1,
              disabled = function () return not db.enabled end},
            secret = {type = "toggle", name = "Hidden", order = 3, hidden = true},
            mode = {type = "select", name = "Mode", order = 4, values = {a = "Alpha", b = "Beta"}, sorting = {"b", "a"}},
            alias = {type = "select", style = "radio", name = "Aliases", order = 4.2,
              values = {[""] = "New alias", rld = "/rld -> /reload"}, sorting = {"", "rld"}},
            always = {type = "toggle", name = "Always available", order = 4.5, disabled = false},
            font = {type = "select", name = "Font", order = 5, dialogControl = "LSM30_Font",
              values = {[""] = "Use UI font", Friz = "Fonts\\Friz.ttf"}, get = function () return "Friz" end, set = noop},
            last = {type = "description", name = "Last |cffffd100command|r |cffffd200profile|r |cffff0000warning|r", order = -1},
          },
        },
        frames = {type = "multiselect", name = "Windows", order = 2, values = {ChatFrame1 = "General", ChatFrame3 = "Trade"},
          get = function (_, key) return db.frames[key] end, set = function (_, key, value) db.frames[key] = value end},
        color = {type = "color", name = "Color", desc = "Choose the text color", order = 3, hasAlpha = true,
          get = function () return unpack(db.color) end, set = function (_, ...) db.color = {...} end},
        text = {type = "input", name = "Text", desc = "Edit this text", usage = "Enter valid text", order = 4, get = function () return db.text end,
          set = function (_, value) db.text = value end,
          validate = function (_, value)
            if value == "invalid" then return false end
            return value ~= "bad" or "Rejected"
          end, confirm = function (_, value) return value == "confirmed" and "Save text?" end},
        command = {type = "group", name = "", inline = true, order = 5, args = {
          command = {type = "description", name = "/glassy", order = 1},
          explanation = {type = "description", name = "Open settings", order = 2},
          hidden = {type = "description", name = "Hidden help", order = 3, hidden = true},
        }},
      },
    },
    profile = {
      type = "group", name = "Profiles", order = 2, handler = handler,
      confirm = function (_, value) return value == "Confirmed" and "Create profile?" end,
      args = {
        choose = {type = "select", name = "Profile", arg = "common", values = "List", get = "GetProfile", set = "SetProfile",
          confirm = function (_, value) return value == "Raid" and "Switch to Raid?" end},
        new = {type = "input", name = "New", arg = "common", order = 3, get = false, set = "SetProfile"},
        copyfrom = {type = "select", name = "Copy from", arg = "common", order = 4, get = false, set = "CopyProfile", values = "List"},
        literal = {type = "description", name = "List", order = 5},
        reset = {type = "execute", name = "Reset", order = 2, func = function () db.text = "reset" end, confirm = true,
          confirmText = "Really reset?"},
      },
    },
  },
}
registry:RegisterOptionsTable("Glassy", options)

local updateListeners = {}
local module = {skin = {
  Font = function (font) font:SetFont("game-skin-font.ttf", 10, "OUTLINE") end,
  Button = function () error("Panel buttons must use the native options style") end,
  EditBox = function () error("Panel inputs must use the native options style") end,
  Panel = function () error("Panel surfaces must use the native options style") end,
  ScrollBar = noop,
}}
local core = {
  Libs = {AceConfigRegistry = registry},
  defaults = {profile = {enabled = true, size = 12, color = {r = 1, g = 1, b = 1}, chatFadeInDuration = 0.4}},
  db = {RegisterCallback = noop, profile = {enabled = false, size = 30, color = {r = 0, g = 0, b = 0}}},
  GetModule = function () return module end,
  Subscribe = function (_, _, callback) updateListeners[#updateListeners + 1] = callback end,
}
local utils = {}
assert(loadfile("Glassy/utils.lua"))("Glassy", {core, {}, utils})
utils.notify = function (text) printed = text end
assert(loadfile("Glassy/Modules/EllesmereOptions.lua"))("Glassy", {core, {EVENTS = {UPDATE_CONFIG = "update"}}, utils})
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
assert(row("Appearance").args[1] == "Appearance settings", "Group headings keep their descriptions")
local commandHelp
local themedHighlight
for _, frame in ipairs(frames) do
  if frame.text == "/glassy  Open settings" then
    commandHelp = true
    assert(frame.nativeFont and frame.font[1] == EllesmereUI.EXPRESSWAY and frame.font[2] == 14,
      "Descriptions use the options house font rather than the in-game skin font")
    assert(frame.textColor[4] == 0.53, "Description text uses the native dim color")
  end
  if frame.text == "Last |cff1acc99command|r |cff1acc99profile|r |cffff0000warning|r" then themedHighlight = true end
  assert(not tostring(frame.text):find("Hidden help", 1, true), "Hidden descriptions stay out of merged help rows")
end
assert(commandHelp, "Command help keeps its inline description layout")
assert(themedHighlight, "Gold command emphasis follows the native panel accent while other explicit colors are preserved")
local toggle = row("Enabled")
assert(toggle.args[1]() == true and toggle.args[3] == "Turns it on", "Inherited getters and tooltips are used")
local slider = row("Size")
assert(slider.args[1] == 1 and slider.args[2] == 100 and slider.args[3] == 1, "Sliders retain the complete allowed range for typed values")
assert(slider.alpha == 1, "Enabled rows are not dimmed")
local dropdown = row("Mode")
assert(dropdown.args[1].b == "Beta" and dropdown.args[4][1] == "b", "Dropdowns keep the option's sorting")
local newAlias, savedAlias = row("New alias"), row("/rld -> /reload")
assert(row("Aliases").kind == "SectionHeader" and newAlias.kind == "Checkbox" and savedAlias.kind == "Checkbox")
assert(newAlias.args[1]() and not savedAlias.args[1]())
savedAlias.args[2](true)
savedAlias.args[2](false)
assert(not newAlias.args[1]() and savedAlias.args[1](), "Radio choices are visible and selecting one unchecks the other")
assert(row("Font").args[1].Friz == "Friz" and row("Font").args[1][""] == "Use UI font", "Font pickers preserve the inherited font label")
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
row("Size").args[5](18)
assert(db.size == 12, "Disabled callbacks cannot change settings")
options.args.general.args.appearance.disabled = true
build(1)
assert(row("Always available").alpha == 1, "A child can override inherited disabled state")
options.args.general.args.appearance.disabled = nil
row("Enabled").args[2](true)
runTimers()
build(1)

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
options.args.general.args.frames.confirm = function (_, key, value)
  assert(key == "ChatFrame3" and value == false)
  return "Disable Trade?"
end
row("Trade").args[2](false)
assert(db.frames.ChatFrame3 and popup.text == "Disable Trade?", "Multiselect confirmations receive the changed key and value")
options.args.general.args.frames.disabled = true
popup.data()
assert(db.frames.ChatFrame3, "A pending confirmation cannot apply a setting that became disabled")
options.args.general.args.frames.disabled = nil
popup.data()
assert(db.frames.ChatFrame3 == false)

-- Text inputs validate before they are saved.
local input
for _, frame in ipairs(frames) do if frame.scripts.OnEnterPressed then input = frame end end
db.text = "changed elsewhere"
input.text = "stale draft"
input.scripts.OnEditFocusLost(input)
assert(db.text == "changed elsewhere", "A stale draft never overwrites a newly selected alias or profile")
db.text = "old"
input.text = "bad"
input.scripts.OnEnterPressed(input)
assert(db.text == "old" and printed == "Rejected", "Invalid input is reported and not saved")
printed = nil
input.scripts.OnEditFocusLost(input)
assert(printed == nil, "Leaving the box does not report the same rejection twice")
local accept
for _, frame in ipairs(frames) do if frame.scripts.OnClick then accept = frame end end
assert(rawget(input, "template") == nil and input.font[1] == EllesmereUI.EXPRESSWAY and input.font[2] == 13,
  "Inputs use the options house font without Blizzard input artwork")
assert(input.nativeBorder and input.background.textureColor[4] == 0.5 and input.parent.nativeRow,
  "Input surfaces use the native rounded border, dark fill, and alternating row background")
assert(accept.nativeButton and rawget(accept, "template") == nil and accept.label.font[1] == EllesmereUI.EXPRESSWAY,
  "Accept uses EllesmereUI's native button primitive")
input.text = "new"
input.scripts.OnTextChanged(input, true)
accept.scripts.OnClick(accept)
assert(db.text == "new", "Accept saves text without Enter, since other buttons never take its focus")
input.text = "invalid"
input.scripts.OnTextChanged(input, true)
input.scripts.OnEnterPressed(input)
assert(printed == "Enter valid text" and db.text == "new", "Boolean validation failures report the option usage")
input.text = "confirmed"
input.scripts.OnTextChanged(input, true)
input.scripts.OnEnterPressed(input)
assert(db.text == "new" and popup.text == "Save text?", "Inputs honor confirmations")
popup.data()
assert(db.text == "confirmed")
assert(input.points[1][1] == "BOTTOMLEFT" and input.points[2][1] == "RIGHT", "Single-line inputs fit between row margins and Accept")
local inputTooltip
for _, frame in ipairs(frames) do
  if frame.scripts.OnEnter then
    frame.scripts.OnEnter(frame)
    if shownTooltip == "Edit this text" then inputTooltip = true end
  end
end
assert(inputTooltip, "Input descriptions are available as tooltips")
row("Color").scripts.OnEnter()
assert(shownTooltip == "Choose the text color", "Color descriptions are available as tooltips")

options.args.general.args.text.multiline = 4
build(1)
local multilineInput
for _, frame in ipairs(frames) do
  if frame.frameType == "EditBox" then multilineInput = frame end
end
assert(multilineInput and multilineInput.font[1] == EllesmereUI.EXPRESSWAY and multilineInput.font[2] == 13,
  "Multiline text uses the same house font as single-line inputs")
assert(rawget(multilineInput, "template") == nil and multilineInput.parent.parent.nativeBorder,
  "Multiline input containers use the same native rounded surface")
options.args.general.args.text.multiline = nil

-- Handler method names, info.arg, and confirmations work like AceConfig.
build(2)
local profile = row("Profile")
assert(profile.args[2]() == "Default" and profile.args[1].Raid == "Raid")
profile.args[3]("Raid")
assert(profiles.current == "Default" and popup.text == "Switch to Raid?", "Confirmations wait for the player")
popup.data()
assert(profiles.current == "Raid")
local newProfile
for _, frame in ipairs(frames) do if frame.scripts.OnEnterPressed then newProfile = frame end end
newProfile.text = "Confirmed"
newProfile.scripts.OnEnterPressed(newProfile)
assert(profiles.current == "Raid" and popup.text == "Create profile?", "New profiles inherit their handler and confirmation")
popup.data()
assert(profiles.current == "Confirmed")
build(2)
assert(row("Profile").args[1].Confirmed == "Confirmed", "Profile lists are rebuilt after creating a profile")
assert(row("Copy from").args[2]() == nil, "Copy profile controls have no persistent selection")
row("Copy from").args[3]("Raid")
assert(profiles.copied == "Raid", "Copy actions preserve inherited handlers")
local literal
for _, frame in ipairs(frames) do if frame.text == "List" then literal = true end end
assert(literal, "Literal labels never invoke matching handler methods")
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
