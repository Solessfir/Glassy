local function noop() end
local accent = {r = 0.2, g = 0.6, b = 0.9, a = 0.8}
local profile = {tabStyle = "minimal"}
local core = {
  Components = {}, Libs = {AceHook = {Embed = function (_, object) return object end}},
  db = {profile = profile}, GetThemeColor = function () return accent end,
}
local constants = {ACTIONS = {}, EVENTS = {}, COLORS = {apache = {r = 1, g = 0.8, b = 0.3}}}
local function loadAddonFile(path)
  assert(loadfile(path))("Glassy", {core, constants, {}})
end
local function texture(file, atlas)
  return {
    file = file, atlas = atlas,
    GetTexture = function (self) return self.file end,
    GetAtlas = function (self) return self.atlas end,
    SetTexture = function (self, value) self.file, self.atlas = value, nil end,
    SetAtlas = function (self, value) self.file, self.atlas = nil, value end,
    SetVertexColor = function (self, ...) self.color = {...} end,
    SetColorTexture = function (self, ...) self.color = {...} end,
    SetTextureSliceMargins = function (self, ...) self.margins = {...} end,
    SetPoint = noop,
    SetHeight = function (self, height) self.height = height end,
    Hide = function (self) self.shown = false end,
    Show = function (self) self.shown = true end,
  }
end
local function host()
  return {CreateTexture = function () return texture() end}
end
loadAddonFile("Glassy/Components/ChatTabStyle.lua")
local render = core.Components.RenderChatTabStyle
local frame = host()
render(frame, "minimal", "selected")
assert(not frame.glassyStyleLayers, "The default style must not add artwork")
assert(core.Components.GetChatTabStyle() == "minimal")
profile.tabStyle = "unknown"
assert(core.Components.GetChatTabStyle() == "minimal", "Unknown saved styles fall back safely")

for _, name in ipairs({"framed", "solid", "underline", "pill", "glossy"}) do
  profile.tabStyle = name
  assert(core.Components.GetChatTabStyle() == name)
  for _, state in ipairs({"normal", "hover", "selected"}) do
    render(frame, name, state)
    local layers = frame.glassyStyleLayers
    assert(layers[1].shown == (name ~= "underline"))
    assert(layers[2].shown == (name == "glossy"))
    assert(layers[3].shown == (name == "framed" or name == "pill" or name == "glossy"))
    assert(layers[4].shown == (name == "underline" and state ~= "normal"))
  end
  render(frame, name, "hidden")
  for _, layer in ipairs(frame.glassyStyleLayers) do
    assert(not layer.shown, "Moving selections must replace the tab's entire selected artwork")
  end
end
render(frame, "underline", "selected")
local bar = frame.glassyStyleLayers[4]
assert(bar.height == 3 and bar.color[1] == accent.r and bar.color[4] == 1)
render(frame, "solid", "selected")
local fill = frame.glassyStyleLayers[1]
assert(fill.color[1] == accent.r and fill.color[2] == accent.g and fill.color[3] == accent.b)
assert(math.abs(fill.color[4] - 0.95) < 0.0001)
accent = {r = 1, g = 0, b = 0, a = 1}
render(frame, "solid", "selected")
assert(fill.color[1] == 1 and fill.color[2] == 0, "Style accents must follow live theme changes")
UnitClass = function () return "Mage", "MAGE" end
RAID_CLASS_COLORS = {MAGE = {r = 0.25, g = 0.8, b = 0.92}}
profile.tabAccentClassColor = true
render(frame, "solid", "selected")
assert(fill.color[1] == 0.25 and fill.color[2] == 0.8, "Classic player class colors apply to the selected fill")
render(frame, "solid", "hover")
assert(fill.color[1] ~= 0.25, "Class color does not change the hover fill")
C_ClassColor = {GetClassColor = function () return {r = 0.19, g = 0.75, b = 0.86} end}
render(frame, "underline", "selected")
assert(bar.color[1] == 0.19 and bar.color[3] == 0.86, "The modern class color API also applies to other accents")
profile.tabAccentClassColor = false
render(frame, "classic", "selected")
for _, layer in ipairs(frame.glassyStyleLayers) do assert(not layer.shown) end

Mixin = function (object, mixin)
  for key, value in pairs(mixin) do if key ~= "Init" then object[key] = value end end
  object.Init = noop
  return object
end
loadAddonFile("Glassy/Components/ChatTab.lua")
for _, keyed in ipairs({false, true}) do
  local name = "GlassyStyleTestTab"
  local tab, artwork = host(), {}
  tab.GetName = function () return name end
  _G[name] = tab
  for _, prefix in ipairs(keyed and {"", "Active", "Highlight"} or {"", "Selected", "Highlight"}) do
    for _, side in ipairs({"Left", "Middle", "Right"}) do
      local key = prefix..side
      local region = key == "Left" and texture(nil, "native-atlas") or texture("native-"..key)
      artwork[#artwork + 1] = {region = region, file = region.file, atlas = region.atlas}
      if keyed then tab[key] = region else _G[name..key] = region end
    end
  end
  local chat = {GetName = function () return "GlassyStyleTest" end, isTemporary = true}
  tab = core.Components.CreateChatTab({chatFrame = chat}, {})
  tab.chatFrame = chat
  tab:ClearBackgroundTextures()
  for _, art in ipairs(artwork) do assert(art.region.file == nil and art.region.atlas == nil) end
  for _ = 1, 2 do
    profile.tabStyle = "classic"
    SELECTED_CHAT_FRAME = chat
    tab:UpdateVisualState()
    for _, art in ipairs(artwork) do
      assert(art.region.file == art.file and art.region.atlas == art.atlas, "Classic restores original files and atlases")
    end
    profile.tabStyle = "pill"
    tab:UpdateVisualState()
    for _, art in ipairs(artwork) do assert(art.region.file == nil and art.region.atlas == nil) end
    assert(tab.glassyStyleLayers[1].shown, "Whisper and detached tabs also receive the style")
    tab.glassySelectionAnimated = true
    tab:UpdateVisualState()
    for _, layer in ipairs(tab.glassyStyleLayers) do assert(not layer.shown) end
    tab.glassySelectionAnimated = false
    tab:ClearBackgroundTextures()
  end
  for _, prefix in ipairs({"", "Selected", "Highlight"}) do
    for _, side in ipairs({"Left", "Middle", "Right"}) do _G[name..prefix..side] = nil end
  end
  _G[name] = nil
end

local text = {
  color = {0.9, 0.3, 0.8, 0.65},
  GetTextColor = function (self) return unpack(self.color) end,
  SetAlpha = function (self, alpha) self.alpha = alpha end,
}
local tab = host()
tab.GetName = function () return "GlassyContrastTestTab" end
_G.GlassyContrastTestTab = tab
tab = core.Components.CreateChatTab({chatFrame = {GetName = function () return "GlassyContrastTest" end}}, {})
tab.Text, tab.chatFrame = text, {isTemporary = true}
tab.glassyHooks.hooks = {[text] = {SetTextColor = function (target, ...) target.color = {...} end}}
SELECTED_CHAT_FRAME = tab.chatFrame
profile.tabStyle, accent = "solid", {r = 1, g = 0.8, b = 0.2, a = 0.1}
tab:UpdateVisualState()
assert(text.color[1] == 0 and text.color[2] == 0 and text.color[4] == 1,
  "A bright Solid fill needs dark whisper names regardless of the configured text opacity")
accent = {r = 0, g = 0.1, b = 0.2, a = 1}
tab:UpdateVisualState()
assert(text.color[1] == 1 and text.color[2] == 1, "A dark Solid fill needs light text")
profile.tabStyle = "minimal"
tab:UpdateVisualState()
assert(text.color[1] == 0.9 and text.color[2] == 0.3 and text.color[3] == 0.8 and text.color[4] == 0.65,
  "Leaving Solid restores the native whisper color and opacity")
tab.chatFrame.isTemporary = false
profile.tabStyle, accent = "solid", {r = 1, g = 0.8, b = 0.2, a = 1}
tab:UpdateVisualState()
assert(text.color[1] == 0 and text.alpha == 1, "Regular selected names also contrast with Solid")
profile.tabStyle = "minimal"
tab:UpdateVisualState()
assert(text.color[1] == accent.r and text.color[2] == accent.g, "Other styles keep configured name colors")
_G.GlassyContrastTestTab = nil
print("PASS: all seven tab styles, live accents, animated handoff, detached tabs and reversible native artwork")
