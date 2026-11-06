local Core, Constants = unpack(select(2, ...))
local Hyperlinks = Core:GetModule("Hyperlinks")

local OpenNews = Constants.ACTIONS.OpenNews
local L = function (text) return Core:Localize(text) end

local HYPERLINK_CLICK = Constants.EVENTS.HYPERLINK_CLICK
local HYPERLINK_ENTER = Constants.EVENTS.HYPERLINK_ENTER
local HYPERLINK_LEAVE = Constants.EVENTS.HYPERLINK_LEAVE

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local BattlePetToolTip_ShowLink = BattlePetToolTip_ShowLink
local BattlePetTooltip = BattlePetTooltip
local GameTooltip = GameTooltip
local ShowUIPanel = ShowUIPanel
local UIParent = UIParent
local strsplit = strsplit
-- luacheck: pop

local linkTypes = {
  item = true,
  enchant = true,
  spell = true,
  quest = true,
  achievement = true,
  currency = true,
  battlepet = true,
}

-- Recipes linked from a profession window can be tracked straight from chat on clients with recipe tracking.
local function showRecipeMenu(recipeID, text)
  local TradeSkill, MenuUtil = _G.C_TradeSkillUI, _G.MenuUtil
  if not (TradeSkill and TradeSkill.SetRecipeTracked and TradeSkill.IsRecipeTracked
    and MenuUtil and MenuUtil.CreateContextMenu) then
    return false
  end
  local name = type(text) == "string" and text:match("%[(.-)%]") or nil
  MenuUtil.CreateContextMenu(nil, function (_, rootDescription)
    if name then rootDescription:CreateTitle(name) end
    local tracked = TradeSkill.IsRecipeTracked(recipeID, false)
    rootDescription:CreateButton(L(tracked and "Untrack Recipe" or "Track Recipe"), function ()
      TradeSkill.SetRecipeTracked(recipeID, not tracked, false)
    end)
  end)
  return true
end

local function eachElement(rootDescription, text, callback)
  if not rootDescription.EnumerateElementDescriptions then return end
  for _, description in rootDescription:EnumerateElementDescriptions() do
    if _G.MenuUtil.GetElementText(description) == text and description.SetResponder then
      callback(description)
    end
  end
end

-- Menus opened from Glassy links lack the chat frame they came from, and only Blizzard's own menus
-- may write to the clipboard, so these entries are redirected while Glassy handles a click.
function Hyperlinks:ModifyLinkMenus()
  local Menu, MenuUtil = _G.Menu, _G.MenuUtil
  if not (Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.GetElementText) then return end

  local copyText = _G.COPY_CHARACTER_NAME
  if copyText then
    local function redirectCopy(_, rootDescription, contextData)
      local name = contextData and contextData.name
      if not self.handlingClick or not (not _G.canaccessvalue or _G.canaccessvalue(name)) then return end
      -- Battle.net names arrive as protected |K strings that only Blizzard's copy can resolve.
      if type(name) ~= "string" or name:find("|K", 1, true) then return end
      eachElement(rootDescription, copyText, function (description)
        description:SetResponder(function ()
          Core:GetModule("ChatCopy"):ShowText(L("Glassy: Copy name"), name)
        end)
      end)
    end
    for _, which in ipairs({"FRIEND", "FRIEND_OFFLINE", "BN_FRIEND", "BN_FRIEND_OFFLINE", "CHAT_ROSTER", "PLAYER",
      "PARTY", "RAID_PLAYER", "GUILD", "GUILD_OFFLINE", "COMMUNITIES_WOW_MEMBER", "COMMUNITIES_GUILD_MEMBER"}) do
      Menu.ModifyMenu("MENU_UNIT_"..which, redirectCopy)
    end
  end

  local moveText = _G.MOVE_TO_NEW_WINDOW
  local ChatFrameUtil = _G.ChatFrameUtil
  local popOutChat = ChatFrameUtil and ChatFrameUtil.PopOutChat
  if moveText and popOutChat then
    Menu.ModifyMenu("MENU_CHAT_FRAME_CHANNEL", function (_, rootDescription)
      local chatFrame, link = self.clickedChatFrame, self.clickedLink
      if not self.handlingClick or not chatFrame or type(link) ~= "string" then return end
      -- Links read "channel:CHANNEL:2" or "channel:GUILD"; PopOutChat expects the upper-case type.
      local _, chatType, chatTarget = strsplit(":", link)
      if not chatType then return end
      eachElement(rootDescription, moveText, function (description)
        description:SetResponder(function ()
          popOutChat(chatFrame, chatType:upper(), chatTarget)
        end)
      end)
    end)
  end
end

function Hyperlinks:OnInitialize()
  self.state = {
    showingTooltip = nil
  }
end

function Hyperlinks:OnEnable()
  -- Custom hyperlink for [See what's new]
  _G.hooksecurefunc("SetItemRef", function(link)
    local linkType, addon, param1 = strsplit(":", link)
    if linkType == "garrmission" and addon == "Glassy" then
      if param1 == "opennews" then
        Core:Dispatch(OpenNews())
      end
    end
  end)

  Core:Subscribe(HYPERLINK_CLICK, function (payload)
    local link, text, button, chatFrame = unpack(payload)
    local accessible = not _G.canaccessvalue or _G.canaccessvalue(link)
    if accessible and button == "RightButton" then
      local recipeID = tonumber(link:match("^enchant:(%d+)"))
      if recipeID and showRecipeMenu(recipeID, text) then return end
    end

    -- Right-click menus would anchor to the hidden native chat frame and not show, so only
    -- left clicks receive it. The channel menu gets it below for "Move to New Window".
    self.clickedChatFrame, self.clickedLink = chatFrame, accessible and link or nil
    self.handlingClick = true
    -- Use global reference in case some addon has hooked into it for custom
    -- hyperlinks (e.g. Mythic Dungeon Tools, Prat)
    local ok, err = pcall(_G.SetItemRef, link, text, button, button ~= "RightButton" and chatFrame or nil)
    self.handlingClick = false
    if not ok then _G.geterrorhandler()(err) end
  end)

  self:ModifyLinkMenus()

  Core:Subscribe(HYPERLINK_ENTER, function (payload)
    local link, text = unpack(payload)
    local t = string.match(link, "^(.-):")

    if linkTypes[t] then
      if t == "battlepet" then
        self.state.showingTooltip = BattlePetTooltip
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        BattlePetToolTip_ShowLink(text)
      else
        self.state.showingTooltip = GameTooltip
        ShowUIPanel(GameTooltip)
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
      end
    end
  end)

  Core:Subscribe(HYPERLINK_LEAVE, function (link)
    if self.state.showingTooltip then
      self.state.showingTooltip:Hide()
      self.state.showingTooltip = false
    end
  end)
end
