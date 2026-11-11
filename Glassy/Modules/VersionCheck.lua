local Core, _, Utils = unpack(select(2, ...))
local VersionCheck = Core:GetModule("VersionCheck")

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_ChatInfo = C_ChatInfo
local CreateFrame = CreateFrame
local IsInGroup = IsInGroup
local IsInGuild = IsInGuild
local IsInRaid = IsInRaid
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE
-- luacheck: pop

local PREFIX = "Glassy"

-- Prereleases and development builds are never announced or compared.
local function isRelease(version)
  return type(version) == "string" and version:match("^%d+%.%d+%.%d+$") ~= nil
end

local function canAccess(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

local function send(channel, target)
  if not channel or not isRelease(Core.Version)
    or (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
  then
    return
  end
  C_ChatInfo.SendAddonMessage(PREFIX, Core.Version, channel, target)
end

local function groupChannel()
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  elseif IsInRaid() then
    return "RAID"
  elseif IsInGroup() then
    return "PARTY"
  end
end

function VersionCheck:OnEnable()
  if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
    return
  end
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

  local notified, lastGroup = false, nil
  -- Older senders get one reply each, so people who join later still hear about the newer version.
  local replied = {}

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:SetScript("OnEvent", function (_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      local prefix, version, _, sender = ...
      if not canAccess(prefix) or prefix ~= PREFIX or not canAccess(version) or not isRelease(version) then
        return
      end
      if Utils.versionGreaterThan(version, Core.Version) then
        if not notified then
          notified = true
          Utils.notify(string.format(Core:Localize("A newer version is available: %s"), version))
        end
      elseif canAccess(sender) and Utils.versionGreaterThan(Core.Version, version) and not replied[sender] then
        replied[sender] = true
        send("WHISPER", sender)
      end
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      local isLogin, isReload = ...
      if (isLogin or isReload) and IsInGuild() then
        send("GUILD")
      end
    end
    -- Roster updates repeat often, so announce only on joining a group or switching to an instance group.
    local group = groupChannel()
    if group ~= lastGroup then
      lastGroup = group
      send(group)
    end
  end)
end
