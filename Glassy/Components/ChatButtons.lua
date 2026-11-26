local Core, Constants = unpack(select(2, ...))

local BUTTON_NAMES = {
  "QuickJoinToastButton",
  "ChatFrameChannelButton",
  "ChatFrameToggleVoiceDeafenButton",
  "ChatFrameToggleVoiceMuteButton",
  "ChatFrameMenuButton",
}

local POSITIONS = {
  left = {"TOPRIGHT", "TOPLEFT", -2, 0},
  right = {"TOPLEFT", "TOPRIGHT", 2, 0},
  topleft = {"BOTTOMLEFT", "TOPLEFT", 0, 2},
  topright = {"BOTTOMRIGHT", "TOPRIGHT", 0, 2},
  bottomleft = {"TOPLEFT", "BOTTOMLEFT", 0, -2},
  bottomright = {"TOPRIGHT", "BOTTOMRIGHT", 0, -2},
}

local ChatButtonsMixin = {}
Core.Components.ChatButtonsMixin = ChatButtonsMixin

function ChatButtonsMixin:CanChangeLayout()
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    for _, button in ipairs(self.buttons) do
      if button.IsProtected and button:IsProtected() then return false end
    end
  end
  return true
end

function ChatButtonsMixin:Layout()
  if self.layingOut or not self:CanChangeLayout() then return end
  self.layingOut = true
  local side = Core.db.profile.chatButtonsSide
  if not POSITIONS[side] then side = "right" end
  local position = POSITIONS[side]
  local vertical = side == "left" or side == "right"
  local reverse = side == "topright" or side == "bottomright"
  self:ClearAllPoints()
  self:SetPoint(position[1], self.container, position[2],
    position[3] + (tonumber(Core.db.profile.chatButtonsOffsetX) or 0),
    position[4] + (tonumber(Core.db.profile.chatButtonsOffsetY) or 0))

  local previous
  for index = 1, #self.buttons do
    local button = self.buttons[reverse and (#self.buttons - index + 1) or index]
    if button:GetParent() ~= self then button:SetParent(self) end
    if button:IsShown() then
      button:ClearAllPoints()
      if not previous then
        button:SetPoint(position[1], self, position[1], 0, 0)
      elseif vertical then
        button:SetPoint("TOP", previous, "BOTTOM", 0, -2)
      elseif reverse then
        button:SetPoint("RIGHT", previous, "LEFT", -2, 0)
      else
        button:SetPoint("LEFT", previous, "RIGHT", 2, 0)
      end
      previous = button
    end
  end
  self.layingOut = nil
end

function ChatButtonsMixin:Update()
  if not self:CanChangeLayout() then return end
  self:SetShown(not not Core.db.profile.chatButtons)
  self:Layout()
end

function ChatButtonsMixin:CollectButtons()
  local buttons = {}
  for _, name in ipairs(BUTTON_NAMES) do
    local button = _G[name]
    if button then buttons[#buttons + 1] = button end
    if button and not self.knownButtons[button] then
      self.knownButtons[button] = true
      self.container:AddHoverRegion(button)
      -- Keep Blizzard's click handlers, tooltips, voice state and menu generation intact.
      button:HookScript("OnShow", function () self:Layout() end)
      button:HookScript("OnHide", function () self:Layout() end)
      _G.hooksecurefunc(button, "SetPoint", function () self:Layout() end)
      _G.hooksecurefunc(button, "SetParent", function () self:Layout() end)
    end
  end
  self.buttons = buttons
  self:Update()
end

Core.Components.CreateChatButtons = function (container, dock)
  local frame = _G.CreateFrame("Frame", nil, dock)
  local object = _G.Mixin(frame, ChatButtonsMixin)
  object.container = container
  object.buttons, object.knownButtons = {}, {}
  object:SetSize(1, 1)
  object:RegisterEvent("ADDON_LOADED")
  object:RegisterEvent("PLAYER_REGEN_ENABLED")
  object:SetScript("OnEvent", function () object:CollectButtons() end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "chatButtons" or key == "chatButtonsSide" or key == "chatButtonsOffsetX" or key == "chatButtonsOffsetY" then
      object:Update()
    end
  end)
  object:CollectButtons()
  return object
end
