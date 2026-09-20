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

local function getLeftTextPadding()
    return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

function ScrollOverlayFrame:UpdateUnreadLayout()
    self.icon:ClearAllPoints()
    self.icon:SetPoint(
      "BOTTOMLEFT",
      getLeftTextPadding(),
      math.max(0, (self.unreadRowHeight - self.icon:GetHeight()) / 2)
    )
end

function ScrollOverlayFrame:GetUnreadRowHeight()
    return self.unreadRowHeight or MIN_UNREAD_ROW_HEIGHT
end

function ScrollOverlayFrame:SetUnreadRowHeight(rowHeight)
    self.unreadRowHeight = math.max(MIN_UNREAD_ROW_HEIGHT, rowHeight or MIN_UNREAD_ROW_HEIGHT)
    self:SetHeight(self.unreadRowHeight)

    if self.snapToBottomFrame then
      self.snapToBottomFrame:SetHeight(self.unreadRowHeight)
    end
    if self.icon then
      self:UpdateUnreadLayout()
    end
    local parent = self:GetParent()
    if parent and parent.UpdateViewportHeight then
      parent:UpdateViewportHeight(self.unreadRowHeight)
    end
    self:UpdateFrame()
end

function ScrollOverlayFrame:UpdateUnreadBackground()
    local color = Core.db.profile.unreadMessageBackgroundColor
    local parent = self:GetParent()
    local editBox = parent and parent.layoutEditBox
    local anchor = Core.db.profile.editBoxAnchor
    local background = self.snapToBottomFrame
    background:SetGradientBackground(color, color.a)
    if editBox and editBox.glassyEntryVisible and anchor and anchor.position == "BELOW"
      and (tonumber(anchor.yOfs) or 0) <= 0
    then
      -- Share the edit box edge instead of approximating it with pixel offsets.
      background.leftBg:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT")
      background.rightBg:SetPoint("BOTTOMRIGHT", editBox, "TOPRIGHT")
      if not background.rightBg:IsShown() then
        background.centerBg:SetPoint("BOTTOMRIGHT", editBox, "TOPRIGHT")
      end
    end
end

function ScrollOverlayFrame:UpdateFrame()
    local visibleHeight = self:GetParent().config.height
    local topOffset = math.max(0, visibleHeight - self:GetHeight())

    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", 0, -topOffset)
    self:SetPoint("TOPRIGHT", 0, -topOffset)
    if self.snapToBottomFrame then
      self:UpdateUnreadBackground()
    end
end

function ScrollOverlayFrame:Init()
    self.unreadRowHeight = MIN_UNREAD_ROW_HEIGHT
    self:SetHeight(self.unreadRowHeight)
    self:UpdateFrame()
    self:SetFadeInDuration(0.3)
    self:SetFadeOutDuration(0.15)

    -- Down arrow icon
    if self.icon == nil then
      self.icon = self:CreateTexture(nil, "ARTWORK")
    end
    self.icon:SetTexture("Interface\\Addons\\Glassy\\Glassy\\Assets\\snapToBottomIcon")
    self.icon:SetTexCoord(2 / 16, 10 / 16, 1 / 16, 11 / 16)
    self.icon:SetSize(8, 10)

    -- See new messages click area
    if self.snapToBottomFrame == nil then
      self.snapToBottomFrame = CreateFrame("Frame", nil, self)
      local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin
      Mixin(self.snapToBottomFrame, GradientBackgroundMixin)
      GradientBackgroundMixin.Init(self.snapToBottomFrame)
      self.snapToBottomFrame:SetFrameLevel(self:GetFrameLevel())
    end
    self.snapToBottomFrame:SetHeight(self.unreadRowHeight)
    self.snapToBottomFrame:SetPoint("BOTTOMLEFT")
    self.snapToBottomFrame:SetPoint("BOTTOMRIGHT")
    self.snapToBottomFrame:EnableMouse(true)
    self:UpdateUnreadLayout()
    self:UpdateUnreadBackground()

    if self.newMessageAlertFrame == nil then
      self.newMessageAlertFrame = CreateNewMessageAlertFrame(self)
    end

    self.newMessageAlertFrame:QuickHide()

    self.snapToBottomFrame:SetScript("OnEnter", function ()
      self.newMessageAlertFrame:SetHighlighted(true)
      GameTooltip:SetOwner(self.snapToBottomFrame, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(L("Jump to latest message"), 1, 1, 1)
      GameTooltip:Show()
    end)
    self.snapToBottomFrame:SetScript("OnLeave", function ()
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

          if key == "unreadMessageBackgroundColor" or key == "backgroundFade" then
            self:UpdateUnreadBackground()
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
