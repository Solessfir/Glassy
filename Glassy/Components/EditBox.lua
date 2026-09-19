local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook
local LibEasing = Core.Libs.LibEasing
local super = Utils.super

local EditBoxLayoutChanged = Constants.ACTIONS.EditBoxLayoutChanged
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
local Mixin = Mixin
-- luacheck: pop

local EditBoxMixin = {}

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

local function getVerticalPadding()
  return math.max(
    0,
    tonumber(Core.db.profile.editBoxVerticalPadding) or Core.defaults.profile.editBoxVerticalPadding
  )
end

local function getBackgroundEasing()
  local easing = LibEasing[Core.db.profile.editBoxBackgroundEasing]
  return type(easing) == "function" and easing or LibEasing.OutCubic
end

local function hasVisibleBackground()
  local backgroundColor = Core.db.profile.editBoxBackgroundColor
  local separatorColor = Core.db.profile.editBoxMessageSeparatorColor
  return
    (backgroundColor and (tonumber(backgroundColor.a) or 0) > 0) or
    (separatorColor and (tonumber(separatorColor.a) or 0) > 0)
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

function EditBoxMixin:SetBackgroundAlpha(alpha)
  self.glassyBackgroundAlpha = math.max(0, math.min(1, alpha))
  self:UpdateGlassyBackground()
end

function EditBoxMixin:GetBackgroundAlpha()
  return self.glassyBackgroundAlpha or 1
end

function EditBoxMixin:UpdateGlassyBackground()
  local color = Core.db.profile.editBoxBackgroundColor
  local configuredOpacity = math.max(0, math.min(1, tonumber(color and color.a) or 0))
  self:SetGradientBackground(color, configuredOpacity * self:GetBackgroundAlpha())

  if self.messageSeparator then
    self.messageSeparator:SetSeparatorColor(
      Core.db.profile.editBoxMessageSeparatorColor,
      self:GetBackgroundAlpha()
    )
  end

  if configuredOpacity == 0 then
    self.leftBg:Hide()
    self.centerBg:Hide()
    self.rightBg:Hide()
    return
  end

  -- Texture alpha is kept at full strength because the transition is applied directly to the gradient's vertex colors.
  self.leftBg:SetAlpha(1)
  self.centerBg:Show()
  self.centerBg:SetAlpha(1)
  self.rightBg:SetAlpha(1)
end

function EditBoxMixin:UpdateMessageSeparator()
  self.messageSeparator:ClearAllPoints()
  if Core.db.profile.editBoxAnchor.position == "ABOVE" then
    self.messageSeparator:SetPoint("BOTTOMLEFT")
    self.messageSeparator:SetPoint("BOTTOMRIGHT")
  else
    self.messageSeparator:SetPoint("TOPLEFT")
    self.messageSeparator:SetPoint("TOPRIGHT")
  end

  self.messageSeparator:SetSeparatorColor(
    Core.db.profile.editBoxMessageSeparatorColor,
    self:GetBackgroundAlpha()
  )
end

function EditBoxMixin:StopBackgroundAlphaTransition()
  if self.editBoxBackgroundAlphaHandle then
    LibEasing:StopEasing(self.editBoxBackgroundAlphaHandle)
    self.editBoxBackgroundAlphaHandle = nil
  end
  self.editBoxBackgroundAlphaTarget = nil
end

function EditBoxMixin:AnimateBackgroundAlpha(targetAlpha, onFinished)
  self:StopBackgroundAlphaTransition()
  self.editBoxBackgroundAlphaTarget = targetAlpha

  local startAlpha = self:GetBackgroundAlpha()
  if not hasVisibleBackground() or startAlpha == targetAlpha then
    self:SetBackgroundAlpha(targetAlpha == 0 and 1 or targetAlpha)
    self.editBoxBackgroundAlphaTarget = nil
    if onFinished then
      onFinished()
    end
    return
  end

  self.editBoxBackgroundAlphaHandle = LibEasing:Ease(
    function (alpha)
      self:SetBackgroundAlpha(alpha)
    end,
    startAlpha,
    targetAlpha,
    Constants.EDIT_BOX_TRANSITION_DURATION,
    getBackgroundEasing(),
    function ()
      self.editBoxBackgroundAlphaHandle = nil
      self.editBoxBackgroundAlphaTarget = nil
      if onFinished then
        onFinished()
      end
    end
  )
end

function EditBoxMixin:ShowEntry(continueTransition)
  if self.glassyEntryVisible and self.editBoxBackgroundAlphaTarget ~= 0 then
    return
  end

  self.glassyEntryVisible = true
  Core:Dispatch(EditBoxVisibilityChanged(true))
  if self.glassyInitialized then
    if not continueTransition then
      self:StopBackgroundAlphaTransition()
      self:SetBackgroundAlpha(0)
    end
    self:AnimateBackgroundAlpha(1)
  else
    self.glassyInitialized = true
    self:StopBackgroundAlphaTransition()
    self:SetBackgroundAlpha(1)
  end
  self:UpdateDynamicMessageArea()
end

function EditBoxMixin:GetReusableMessageHeight()
  if (
    not Core.db.profile.dynamicEditBox or
    Core.db.profile.editBoxAnchor.position ~= "BELOW" or
    self.glassyEntryVisible
  ) then
    return 0
  end

  local yOffset = tonumber(Core.db.profile.editBoxAnchor.yOfs) or 0
  local bottomPadding = self.header:GetLineHeight() * getVerticalPadding()
  return math.max(0, self:GetHeight() - yOffset - bottomPadding)
end

function EditBoxMixin:UpdateDynamicMessageArea()
  if self.dynamicMessageAreaUpdatePending then
    return
  end

  -- Blizzard hides the edit box synchronously from SendText/ClearChat. Defer
  -- the visual layout work so it does not inherit that already-busy script's
  -- execution budget, and coalesce duplicate Show/Hide updates in one frame.
  self.dynamicMessageAreaUpdatePending = true
  C_Timer.After(0, function ()
    self.dynamicMessageAreaUpdatePending = nil

    local reusableHeight = self:GetReusableMessageHeight()
    self.dynamicMessageArea:SetWidth(Core.db.profile.frameWidth)
    self.dynamicMessageArea:SetHeight(math.max(1, reusableHeight))
    self.dynamicMessageArea:SetShown(reusableHeight > 0)
    Core:Dispatch(EditBoxLayoutChanged())
  end)
end

function EditBoxMixin:Init(parent)
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
  local function updateAnchor()
    self:ClearAllPoints()
    if Core.db.profile.editBoxAnchor.position == "ABOVE" then
      self:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, Core.db.profile.editBoxAnchor.yOfs)
    else
      self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, Core.db.profile.editBoxAnchor.yOfs)
    end
  end
  updateAnchor()

  self:SetFontObject("GlassyEditBoxFont")
  self:SetWidth(Core.db.profile.frameWidth)
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
    self.dynamicMessageArea = CreateFrame("Frame", nil, parent)
    self.dynamicMessageArea:SetPoint("TOPLEFT", parent, "BOTTOMLEFT")
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
      self:SetWidth(Core.db.profile.frameWidth)
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
      updateAnchor()
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

Core.Components.CreateEditBox = function (parent)
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin
  local object = Mixin(_G.ChatFrame1EditBox, GradientBackgroundMixin, EditBoxMixin)
  -- Keep AceHook methods off Blizzard's edit box so other addons can use its native HookScript.
  object.glassyHooks = AceHook:Embed({})
  -- Glassy hides the native chat frame; its input must inherit visibility from Glassy instead.
  object:SetParent(parent)
  GradientBackgroundMixin.Init(object)
  object:Init(parent)
  return object
end
