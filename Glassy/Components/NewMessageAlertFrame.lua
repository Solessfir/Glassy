local Core, Constants = unpack(select(2, ...))

local Colors = Constants.COLORS
local L = function(text) return Core:Localize(text) end
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG
local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local NewMessageAlertFrameMixin = {}
local MIN_UNREAD_ROW_HEIGHT = 24
local UNREAD_VERTICAL_PADDING = 8

function NewMessageAlertFrameMixin:UpdateLayout()
    local lineHeight = self.text:GetLineHeight() or Core.db.profile.messageFontSize
    local rowHeight = math.max(MIN_UNREAD_ROW_HEIGHT, math.ceil(lineHeight + UNREAD_VERTICAL_PADDING))
    self:SetHeight(rowHeight)
    self:GetParent():SetUnreadRowHeight(rowHeight)
end

function NewMessageAlertFrameMixin:SetHighlighted(highlighted)
    if highlighted then
      self.text:SetTextColor(1, 1, 1)
    else
      self.text:SetTextColor(Colors.apache.r, Colors.apache.g, Colors.apache.b)
    end
end

function NewMessageAlertFrameMixin:Init()
    self:SetPoint("BOTTOMLEFT")
    self:SetPoint("BOTTOMRIGHT")
    self:SetFadeInDuration(0.15)
    self:SetFadeOutDuration(0.15)

    -- New messages text
    if self.text == nil then
      self.text = self:CreateFontString(nil, "ARTWORK", "GlassyMessageFont")
    end
    self.text:ClearAllPoints()
    self.text:SetPoint("LEFT", self:GetParent().icon, "RIGHT", 5, 0)
    self.text:SetText(L("Unread messages"))
    self:SetHighlighted(false)
    self:UpdateLayout()

    -- Alert line
    if self.bottomLine == nil then
      self.bottomLine = CreateSeparatorFrame(self)
      self.bottomLine:SetPoint("BOTTOMLEFT")
      self.bottomLine:SetPoint("BOTTOMRIGHT")
    end
    self.bottomLine:SetSeparatorColor(Core.db.profile.unreadMessageSeparatorColor)

    if self.subscriptions == nil then
      self.subscriptions = {
        Core:Subscribe(UPDATE_CONFIG, function (key)
          if key == "font" or key == "messageFontSize" then
            self:UpdateLayout()
          end

          if key == "backgroundFade" or key == "unreadMessageSeparatorColor" then
            self.bottomLine:SetSeparatorColor(Core.db.profile.unreadMessageSeparatorColor)
          end
        end)
      }
    end
end

local function CreateNewMessageAlertFrame(parent)
  local FadingFrameMixin = Core.Components.FadingFrameMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, NewMessageAlertFrameMixin)

  FadingFrameMixin.Init(object)
  NewMessageAlertFrameMixin.Init(object)

  return object
end

Core.Components.CreateNewMessageAlertFrame = CreateNewMessageAlertFrame
