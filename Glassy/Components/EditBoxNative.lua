local Core, Constants, Utils = unpack(select(2, ...))

local super = Utils.super
local EditBoxMixin = Core.Components.EditBoxMixin
local Helpers = Core.Components.EditBoxHelpers
local getVerticalPadding = Helpers.getVerticalPadding
local hasVisibleBackground = Helpers.hasVisibleBackground

local EditBoxVisibilityChanged = Constants.ACTIONS.EditBoxVisibilityChanged
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG
local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_ChatInfo = C_ChatInfo
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus
local InCombatLockdown = InCombatLockdown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
-- luacheck: pop

local EDIT_BOX_RIGHT_PADDING = 8

local function isChatMessagingLocked()
  return C_ChatInfo and
    C_ChatInfo.InChatMessagingLockdown and
    C_ChatInfo.InChatMessagingLockdown()
end

local function setPropagateKeyboardInput(editBox, propagate)
  if InCombatLockdown() then
    return false
  end
  editBox:SetPropagateKeyboardInput(propagate)
  return true
end

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end


local function hideExternalBackgrounds(editBox)
  local name = editBox:GetName()
  for _, suffix in ipairs({"Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight"}) do
    local region = _G[name..suffix]
    if region then
      region:Hide()
    end
  end

  -- Prat places its own backdrop inside Blizzard's edit box, so keep it hidden while Glassy supplies the styling.
  if editBox.pratFrame then
    editBox.pratFrame:Hide()
  end
end


function EditBoxMixin:Init(parent, useParentWidth)
  -- Hide default styling
  hideExternalBackgrounds(self)

  -- Blizzard chat edit boxes default to requiring Alt for cursor movement.
  -- Glassy owns the visible edit box, so use standard arrow-key behavior.
  self:SetAltArrowKeyMode(false)

  self.glassyHooks:RawHook(_G[self:GetName().."Left"], "Show", function () end, true)
  self.glassyHooks:RawHook(_G[self:GetName().."Mid"], "Show", function () end, true)
  self.glassyHooks:RawHook(_G[self:GetName().."Right"], "Show", function () end, true)

  -- Retail shows these focus textures again after Show(), using SetShown().
  for _, key in ipairs({"focusLeft", "focusMid", "focusRight"}) do
    local texture = self[key]
    if texture then texture:SetAlpha(0) end
  end

  -- New styling
  self.glassyParent = parent
  self.glassyUseParentWidth = useParentWidth == true
  self:UpdateAnchor()

  self:SetFontObject("GlassyEditBoxFont")
  self:SetWidth(self:GetLayoutWidth())
  self.header:SetFontObject("GlassyEditBoxFont")

  local function updateHeaderAnchor()
    self.header:ClearAllPoints()
    self.header:SetPoint("LEFT", getLeftTextPadding(), 0)
  end
  updateHeaderAnchor()

  self.glassyBackgroundAlpha = 1
  self:UpdateGlassyBackground()

  if self.messageSeparator == nil then
    self.messageSeparator = CreateSeparatorFrame(self)
  end
  self:UpdateMessageSeparator()

  local Ypadding = self.header:GetLineHeight() * getVerticalPadding()
  self:SetHeight(self.header:GetLineHeight() + Ypadding * 2)

  self.glassyHooks:RawHook(self, "SetTextInsets", function ()
    Ypadding = self.header:GetLineHeight() * getVerticalPadding()
    self.glassyHooks.hooks[self].SetTextInsets(
      self,
      self.header:GetStringWidth() + getLeftTextPadding(),
      EDIT_BOX_RIGHT_PADDING, Ypadding, Ypadding
    )
  end, true)

  self:SetTextInsets()

  if self.dynamicMessageArea == nil then
    self.dynamicMessageArea = CreateFrame("Frame", nil, self.glassyParent)
    self.dynamicMessageArea:SetPoint("TOPLEFT", self.glassyParent, "BOTTOMLEFT")
  end

  -- Workaround for editbox being open on login
  self.glassyInitialized = false

  super(self).HookScript(self, "OnShow", function ()
    hideExternalBackgrounds(self)
    self:ShowEntry(false)
  end)

  local altInputWatcher = CreateFrame("Frame")
  altInputWatcher:Hide()
  altInputWatcher:SetScript("OnUpdate", function (watcher)
    if IsAltKeyDown() or not setPropagateKeyboardInput(self, false) then
      return
    end
    watcher:Hide()
    if self:IsVisible() and not GetCurrentKeyBoardFocus() then
      self:SetFocus()
    end
  end)

  super(self).HookScript(self, "OnKeyDown", function (editBox, key)
    setPropagateKeyboardInput(editBox, false)
    if IsAltKeyDown() and not IsControlKeyDown() then
      -- Leave native history navigation and modifier presses with the edit box.
      if key ~= "UP" and key ~= "DOWN" and key ~= "LEFT" and key ~= "RIGHT"
        and key ~= "LALT" and key ~= "RALT" and key ~= "LSHIFT" and key ~= "RSHIFT"
        and setPropagateKeyboardInput(editBox, true)
      then
        -- Release text focus before the printable character arrives.
        -- WoW handles the actual binding; the draft never needs SetText.
        editBox.glassyClearingFocus = true
        editBox:ClearFocus()
        editBox.glassyClearingFocus = nil
        altInputWatcher:Show()
      end
      return
    end

    if not IsControlKeyDown() or IsAltKeyDown() then
      return
    end

    if isChatMessagingLocked() and (key == "U" or key == "K" or key == "Y") then
      return
    end

    if key == "E" then
      editBox:SetCursorPosition(editBox:GetNumLetters())
    elseif key == "U" then
      local text = editBox:GetText()
      local cursorPosition = editBox:GetCursorPosition()
      local killedText = text:sub(1, cursorPosition)
      if killedText ~= "" then
        editBox.glassyKillBuffer = killedText
      end
      editBox:SetText(text:sub(cursorPosition + 1))
      editBox:SetCursorPosition(0)
    elseif key == "K" then
      local text = editBox:GetText()
      local cursorPosition = editBox:GetCursorPosition()
      local killedText = text:sub(cursorPosition + 1)
      if killedText ~= "" then
        editBox.glassyKillBuffer = killedText
      end
      editBox:SetText(text:sub(1, cursorPosition))
      editBox:SetCursorPosition(cursorPosition)
    elseif key == "Y" and editBox.glassyKillBuffer then
      local text = editBox:GetText()
      local cursorPosition = editBox:GetCursorPosition()
      local newText = text:sub(1, cursorPosition)
        .. editBox.glassyKillBuffer
        .. text:sub(cursorPosition + 1)
      editBox:SetText(newText)
      editBox:SetCursorPosition(math.min(
        cursorPosition + #editBox.glassyKillBuffer,
        #editBox:GetText()
      ))
    end
  end)

  super(self).HookScript(self, "OnHide", function ()
    self:StopBackgroundAlphaTransition()
    self:SetBackgroundAlpha(1)
    if self.glassyEntryVisible then
      self.glassyEntryVisible = false
      Core:Dispatch(EditBoxVisibilityChanged(false))
      self:UpdateDynamicMessageArea()
    end
  end)

  self.glassyHooks:RawHook(self, "Show", function (frame)
    local wasVisible = frame:IsVisible()
    self.glassyHooks.hooks[frame].Show(frame)
    hideExternalBackgrounds(frame)
    if wasVisible and not self.glassyEntryVisible then
      self:ShowEntry(true)
    end
  end, true)

  self.glassyHooks:RawHook(self, "Hide", function (frame)
    if frame.glassyClearingFocus then
      return
    end

    if not frame:IsVisible() then
      self.glassyHooks.hooks[frame].Hide(frame)
      return
    end

    local messageAreaChanged = self.glassyEntryVisible
    if messageAreaChanged then
      self.glassyEntryVisible = false
      Core:Dispatch(EditBoxVisibilityChanged(false))
    end
    self.header:Hide()
    if self.headerSuffix then
      self.headerSuffix:Hide()
    end
    if frame:HasFocus() then
      frame.glassyClearingFocus = true
      frame:ClearFocus()
      frame.glassyClearingFocus = nil
    end
    self:AnimateBackgroundAlpha(0, function ()
      if not self.glassyEntryVisible then
        self.glassyHooks.hooks[frame].Hide(frame)
      end
    end)
    if messageAreaChanged then
      self:UpdateDynamicMessageArea()
    end
  end, true)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "editBoxFontSize" or key == "editBoxVerticalPadding" then
      Ypadding = self.header:GetLineHeight() * getVerticalPadding()
      self:SetHeight(self.header:GetLineHeight() + Ypadding * 2)
      self:SetTextInsets()
    end

    if key == "frameWidth" then
      self:SetWidth(self:GetLayoutWidth())
      self:UpdateGlassyBackground()
      self:UpdateMessageSeparator()
    end

    if key == "textLeftPadding" then
      updateHeaderAnchor()
      self:SetTextInsets()
    end

    if key == "editBoxBackgroundColor" or key == "backgroundFade" then
      self:UpdateGlassyBackground()
      if key == "backgroundFade" then
        self:UpdateMessageSeparator()
      end
      if not hasVisibleBackground() then
        self:StopBackgroundAlphaTransition()
        self:SetBackgroundAlpha(1)
        if not self.glassyEntryVisible and self:IsVisible() then
          self.glassyHooks.hooks[self].Hide(self)
        end
      end
    end

    if key == "editBoxAnchor" then
      self:UpdateAnchor()
      self:UpdateMessageSeparator()
    end

    if key == "editBoxMessageSeparatorColor" then
      self:UpdateMessageSeparator()
    end

    if (
      key == "font" or
      key == "frameWidth" or
      key == "editBoxFontSize" or
      key == "editBoxVerticalPadding" or
      key == "editBoxAnchor" or
      key == "dynamicEditBox"
    ) then
      self:UpdateDynamicMessageArea()
    end
  end)

  self.glassyEntryVisible = self:IsShown()
  Core:Dispatch(EditBoxVisibilityChanged(self.glassyEntryVisible))
  self:UpdateDynamicMessageArea()
  C_Timer.After(0, function ()
    self.glassyInitialized = true
  end)
end

