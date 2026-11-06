local Core, Constants = unpack(select(2, ...))
local Ellesmere = Core:GetModule("Ellesmere")

local UpdateConfig = Constants.ACTIONS.UpdateConfig

-- Colors that follow EllesmereUI's accent while they keep Glassy's defaults.
local ACCENT_KEYS = {
  "tabTextColor",
  "tabHighlightTextColor",
  "tabMessageSeparatorColor",
  "editBoxMessageSeparatorColor",
  "unreadMessageSeparatorColor",
}
local isAccentKey = {}
for _, key in ipairs(ACCENT_KEYS) do isAccentKey[key] = true end

-- Colors saved through WoW's color picker come back as 32-bit floats, so compare within half a color step.
local COLOR_TOLERANCE = 0.5 / 255

local function sameColor(left, right)
  if type(left) ~= "table" or type(right) ~= "table" then return false end
  for _, channel in ipairs({"r", "g", "b"}) do
    if math.abs((tonumber(left[channel]) or 0) - (tonumber(right[channel]) or 0)) > COLOR_TOLERANCE then
      return false
    end
  end
  return true
end

-- An error in EllesmereUI's skinning must never break Glassy's own windows.
local function skinSafely(callback, ...)
  local ok, err = pcall(callback, ...)
  if not ok then _G.geterrorhandler()(err) end
end

local function skinWindow(S, window, parts)
  S.Shell(window.frame)
  for _, child in ipairs({window.frame:GetChildren()}) do
    if child:GetObjectType() == "Button" then
      if child.GetText and child:GetText() == _G.CLOSE then
        S.Button(child)
      elseif child.SetBackdrop then
        -- The status bar is the only other button with a backdrop.
        S.Panel(child, {inset = true})
      end
    end
  end
  for _, part in ipairs(parts or {}) do
    if part.type == "EditBox" then
      S.EditBox(part.editbox)
    elseif part.type == "MultiLineEditBox" then
      S.Panel(part.scrollBG, {inset = true})
      S.ScrollBar(part.scrollBar)
    elseif part.type == "ScrollFrame" then
      S.ScrollBar(part.scrollbar)
    end
  end
end

function Ellesmere:OnInitialize()
  self.pendingWindows = {}
  local EllesmereUI = _G.EllesmereUI
  if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end

  -- EllesmereUI calls this at login only while its skinning is enabled for Glassy.
  EllesmereUI.RegisterSkin("Glassy", function (S)
    self.skin = S
    for _, pending in ipairs(self.pendingWindows) do
      skinSafely(skinWindow, S, pending.window, pending.parts)
    end
    self.pendingWindows = {}
    if S.OnLooksChanged then
      S.OnLooksChanged(function () self:RefreshLooks() end)
    end
    self:RefreshLooks()
  end)
end

function Ellesmere:IsActive()
  return self.skin ~= nil and (not self.skin.IsEnabled or self.skin.IsEnabled())
end

-- Glassy's AceGUI windows are created once and only hidden, so a skinned frame never returns to AceGUI's pool.
function Ellesmere:SkinWindow(window, parts)
  if self.skin then
    skinSafely(skinWindow, self.skin, window, parts)
  else
    self.pendingWindows[#self.pendingWindows + 1] = {window = window, parts = parts}
  end
end

-- The cached accent, only while EllesmereUI still skins Glassy.
function Ellesmere:GetActiveAccent()
  return self:IsActive() and self.accent or nil
end

function Ellesmere:GetAccentColor()
  if not self:IsActive() or not self.skin.GetAccentColor then return nil end
  local r, g, b = self.skin.GetAccentColor()
  if type(r) ~= "number" then return nil end
  return r, g, b
end

function Ellesmere:GetFontPath()
  if not self:IsActive() or not self.skin.GetFont then return nil end
  local path = self.skin.GetFont()
  return type(path) == "string" and path ~= "" and path or nil
end

-- Re-reads the accent and font when EllesmereUI's looks change, then refreshes everything that uses them.
function Ellesmere:RefreshLooks()
  self.accent = nil
  local r, g, b = self:GetAccentColor()
  if r then self.accent = {r = r, g = g, b = b} end
  if not Core.db then return end
  Core:SelectDefaultFont()
  for _, key in ipairs(ACCENT_KEYS) do
    Core:Dispatch(UpdateConfig(key))
  end
  Core:Dispatch(UpdateConfig("emojiDisplay"))
end

local themedColors = {}

-- EllesmereUI's accent while a theme color is left at Glassy's default, otherwise the user's choice.
function Core:GetThemeColor(key)
  local color = self.db.profile[key]
  local accent = isAccentKey[key] and Ellesmere:GetActiveAccent()
  if accent and sameColor(color, self.defaults.profile[key]) then
    local themed = themedColors[key] or {}
    themedColors[key] = themed
    themed.r, themed.g, themed.b, themed.a = accent.r, accent.g, accent.b, color.a
    return themed
  end
  return color
end
