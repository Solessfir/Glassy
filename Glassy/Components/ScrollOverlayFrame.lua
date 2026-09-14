local Core, Constants, Utils = unpack(select(2, ...))

local CreateNewMessageAlertFrame = Core.Components.CreateNewMessageAlertFrame
local L = function(text) return Core:Localize(text) end

local super = Utils.super
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local Mixin = Mixin
-- luacheck: pop

local ScrollOverlayFrame = {}
local MIN_UNREAD_ROW_HEIGHT = 24
local OVERLAY_FADE_HEIGHT = 40

local function getLeftTextPadding()
    return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

function ScrollOverlayFrame:UpdateUnreadLayout()
    self.icon:ClearAllPoints()
    self.icon:SetPoint("BOTTOMLEFT", getLeftTextPadding(), math.max(0, (self.unreadRowHeight - 16) / 2))
end

function ScrollOverlayFrame:SetUnreadRowHeight(rowHeight)
    self.unreadRowHeight = math.max(MIN_UNREAD_ROW_HEIGHT, rowHeight or MIN_UNREAD_ROW_HEIGHT)
    self:SetHeight(self.unreadRowHeight + OVERLAY_FADE_HEIGHT)

    if self.snapToBottomFrame then
      self.snapToBottomFrame:SetHeight(self.unreadRowHeight)
    end
    if self.mask then
      self.mask:ClearAllPoints()
      self.mask:SetSize(16, self:GetHeight())
      self.mask:SetPoint("CENTER", 0, -self:GetHeight() / 2)
    end
    if self.icon then
      self:UpdateUnreadLayout()
    end
    self:UpdateFrame()
end

function ScrollOverlayFrame:UpdateFrame()
    local visibleHeight = self:GetParent().config.height
    local topOffset = math.max(0, visibleHeight - self:GetHeight() + 2)

    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", 0, -topOffset)
    self:SetPoint("TOPRIGHT", 0, -topOffset)
end

function ScrollOverlayFrame:Init()
    self.unreadRowHeight = MIN_UNREAD_ROW_HEIGHT
    self:SetHeight(self.unreadRowHeight + OVERLAY_FADE_HEIGHT)
    self:UpdateFrame()
    self:SetFadeInDuration(0.3)
    self:SetFadeOutDuration(0.15)

    if self.mask == nil then
      self.mask = self:CreateMaskTexture()
    end
    self.mask:SetTexture("Interface\\Addons\\Glassy\\Glassy\\Assets\\overlayMask", "CLAMP", "CLAMPTOBLACKADDITIVE")
    self.mask:SetSize(16, self:GetHeight())
    self.mask:SetPoint("CENTER", 0, -self:GetHeight() / 2)

    local backgroundColor = Core.db.profile.chatBackgroundColor
    self:SetGradientBackground(backgroundColor, backgroundColor.a)

    self.leftBg:AddMaskTexture(self.mask)
    self.centerBg:AddMaskTexture(self.mask)
    self.rightBg:AddMaskTexture(self.mask)

    -- Down arrow icon
    if self.icon == nil then
      self.icon = self:CreateTexture(nil, "ARTWORK")
    end
    self.icon:SetTexture("Interface\\Addons\\Glassy\\Glassy\\Assets\\snapToBottomIcon")
    self.icon:SetSize(16, 16)
    self.icon:SetAlpha(0.85)
    self:UpdateUnreadLayout()

    -- See new messages click area
    if self.snapToBottomFrame == nil then
      self.snapToBottomFrame = CreateFrame("Frame", nil, self)
    end
    self.snapToBottomFrame:SetHeight(self.unreadRowHeight)
    self.snapToBottomFrame:SetPoint("BOTTOMLEFT")
    self.snapToBottomFrame:SetPoint("BOTTOMRIGHT")
    self.snapToBottomFrame:EnableMouse(true)

    if self.newMessageAlertFrame == nil then
      self.newMessageAlertFrame = CreateNewMessageAlertFrame(self)
    end

    self.newMessageAlertFrame:QuickHide()

    self.snapToBottomFrame:SetScript("OnEnter", function ()
      self.icon:SetAlpha(1)
      self.newMessageAlertFrame:SetHighlighted(true)
      GameTooltip:SetOwner(self.snapToBottomFrame, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L("Jump to latest message"), 1, 1, 1)
      GameTooltip:Show()
    end)
    self.snapToBottomFrame:SetScript("OnLeave", function ()
      self.icon:SetAlpha(0.85)
      self.newMessageAlertFrame:SetHighlighted(false)
      if GameTooltip:IsOwned(self.snapToBottomFrame) then
        GameTooltip:Hide()
      end
    end)

    if self.subscriptions == nil then
      self.subscriptions = {
        Core:Subscribe(UPDATE_CONFIG, function (key)
          if key == "frameHeight" or key == "combatLogBarLayout" then
            self:UpdateFrame()
          end

          if key == "textLeftPadding" then
            self:UpdateUnreadLayout()
          end

          if key == "chatBackgroundColor" or key == "backgroundFade" then
            backgroundColor = Core.db.profile.chatBackgroundColor
            self:SetGradientBackground(backgroundColor, backgroundColor.a)
          end
        end)
      }
    end
end

function ScrollOverlayFrame:SetScript(name, callback)
  if name == "OnClickSnapFrame" then
    self.snapToBottomFrame:SetScript("OnMouseUp", function (_, button)
      if button == "LeftButton" then
        self.icon:SetAlpha(0.85)
        self.newMessageAlertFrame:SetHighlighted(false)
        if GameTooltip:IsOwned(self.snapToBottomFrame) then
          GameTooltip:Hide()
        end
        callback()
      end
    end)
    return
  end

  super(self).SetScript(self, name, callback)
end

function ScrollOverlayFrame:ShowNewMessageAlert()
  self.newMessageAlertFrame:Show()
end

function ScrollOverlayFrame:HideNewMessageAlert()
  self.newMessageAlertFrame:Hide()
end

local function CreateScrollOverlayFrame(parent)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, ScrollOverlayFrame)

  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  ScrollOverlayFrame.Init(object)

  return object
end

Core.Components.CreateScrollOverlayFrame = CreateScrollOverlayFrame
