local Core = unpack(select(2, ...))
local ChatLinks = Core:GetModule("ChatLinks")

-- Process visible text only; link payloads, textures and protected names are opaque.
---@param text string
local function mapText(text, transform)
  local parts, cursor, color = {}, 1, ""
  while cursor <= #text do
    local start = text:find("|", cursor, true)
    if not start then
      parts[#parts + 1] = transform(text:sub(cursor), color)
      break
    end
    parts[#parts + 1] = transform(text:sub(cursor, start - 1), color)
    local code = text:sub(start + 1, start + 1)
    local finish
    if code == "H" then
      local label = text:find("|h", start + 2, true)
      finish = label and text:find("|h", label + 2, true)
    elseif code == "T" or code == "A" or code == "K" then
      finish = text:find("|"..code:lower(), start + 2, true)
    elseif code == "c" and text:sub(start + 2, start + 9):match("^%x%x%x%x%x%x%x%x$") then
      finish = start + 8
    elseif code == "c" then
      finish = text:find(":", start + 2, true)
      finish = finish and finish - 1
    else
      finish = start
    end
    -- Incomplete escape sequences cannot safely be interpreted as ordinary chat.
    if not finish then parts[#parts + 1] = text:sub(start); break end
    finish = finish + 1
    parts[#parts + 1] = text:sub(start, finish)
    if code == "c" then color = text:sub(start, finish) elseif code == "r" then color = "" end
    cursor = finish + 1
  end
  return table.concat(parts)
end

local function validName(name)
  if type(name) ~= "string" or #name > 128 then return false end
  local character = name:match("^(.+)%-[%a\128-\255]+$") or name
  return character:match("^[%a\128-\255][%a\128-\255 ]*$") ~= nil
    and character:sub(-1) ~= " " and not character:find("  ", 1, true)
end

local function canInvite()
  local can = _G.CanGroupInvite or (_G.C_PartyInfo and _G.C_PartyInfo.CanInvite)
  return not can or can()
end

local function isAddress(value)
  if value:match("^%a[%w+%.%-]*://%S+$") then return true end
  local host = value:match("^([^/?#]+)")
  if not host then return false end
  local emailHost = host:match('^"[^"]+"@(.+)$') or host:match("^[%w_%.%%+%-]+@(.+)$")
  if emailHost then host = emailHost end
  local address, port = host:match("^(.-):(%d+)$")
  if address then
    if emailHost or tonumber(port) > 65535 then return false end
    host = address
  end
  if host:match("^%d+%.%d+%.%d+%.%d+$") then
    for octet in host:gmatch("%d+") do
      if #octet > 3 or tonumber(octet) > 255 then return false end
    end
    return not emailHost
  end
  local tld = host:match("%.(%a%a+)$")
  if not tld or host:sub(1, 1) == "." or host:find("..", 1, true) then return false end
  for label in host:gmatch("[^%.]+") do
    if not label:match("^[%w_][%w_%-]*[%w_]$") and not label:match("^[%w_]$") then return false end
  end
  return true
end

local function urlLink(value, color)
  return "|cffffffff|Hglassyurl:"..value.."|h["..value.."]|h|r"..color
end

local function formatAddress(word, color)
  local leading, value = word:match("^([%(%[{<\"']*)(.*)$")
  local trailing = ""
  while value ~= "" do
    local last = value:sub(-1)
    local opening = ({[")"] = "(", ["]"] = "[", ["}"] = "{"})[last]
    local trim = last:match("[.,!;:?>\"']") ~= nil
    if opening then
      local _, opens = value:gsub("%"..opening, "")
      local _, closes = value:gsub("%"..last, "")
      trim = closes > opens
    end
    if not trim then break end
    trailing, value = last..trailing, value:sub(1, -2)
  end
  return isAddress(value) and leading..urlLink(value, color)..trailing or word
end

local INVALID_NAMES = {meh = true, now = true, plz = true, pls = true, please = true, when = true,
  group = true, raid = true, grp = true, him = true, her = true, them = true, someone = true}
local SELF_REFERENCES = {me = true, ["for"] = true}
local INVITE_CHANNELS = {SAY = true, YELL = true, WHISPER = true, CHANNEL = true, GUILD = true,
  OFFICER = true, PARTY = true, PARTY_LEADER = true, RAID = true, RAID_LEADER = true, RAID_WARNING = true,
  INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true}

local function inviteLink(text, name, color)
  return "|cffffff00|Hglassyinvite:"..name.."|h["..text.."]|h|r"..color
end

local function formatInvites(text, sender)
  ---@param name string
  local function explicit(phrase, name, color)
    local lower = name:lower()
    if SELF_REFERENCES[lower] then return inviteLink(phrase, sender, color) end
    if #name > 2 and not INVALID_NAMES[lower] and validName(name) then return inviteLink(phrase, name, color) end
  end
  for _, pattern in ipairs({"%f[%a]send%s+invite%s+to%s+([%a\128-\255]+%-?[%a\128-\255]*)",
    "%f[%a]invi?t?e?s?%s+([%a\128-\255]+%-?[%a\128-\255]*)"}) do
    text = mapText(text, function (segment, color)
      local lower, cursor, parts = segment:lower(), 1, {}
      while true do
        local first, last, name = lower:find(pattern, cursor)
        if not first then parts[#parts + 1] = segment:sub(cursor); break end
        local phrase = segment:sub(first, last)
        parts[#parts + 1] = segment:sub(cursor, first - 1)
        parts[#parts + 1] = explicit(phrase, phrase:sub(-#name), color) or phrase
        cursor = last + 1
      end
      return table.concat(parts)
    end)
  end
  text = mapText(text, function (segment, color)
    return (segment:gsub("%f[%a]([Ii][Nn][Vv][Ii]?[Tt]?[Ee]?[Ss]?%f[^%a]%??)", function (word)
      return inviteLink(word, sender, color)
    end))
  end)
  for _, pattern in ipairs({"초대", "組%??$", "組我%??$"}) do
    text = mapText(text, function (segment, color)
      return (segment:gsub(pattern, function (word) return inviteLink(word, sender, color) end))
    end)
  end
  return text
end

function ChatLinks:Format(text)
  if _G.canaccessvalue and not _G.canaccessvalue(text) then return text end
  if type(text) ~= "string" then return text end
  local profile = Core.db.profile
  if profile.chatUrls and not Core:IsPratModuleEnabled("UrlCopy") then
    text = mapText(text, function (segment, color)
      return (segment:gsub('"[^"]+"@[%w_.%-]+%.%a+', function (value)
        return isAddress(value) and urlLink(value, color) or value
      end))
    end)
    text = mapText(text, function (segment, color)
      return (segment:gsub("%S+", function (word) return formatAddress(word, color) end))
    end)
  end
  if profile.chatInvites and not Core:IsPratModuleEnabled("Invites") and canInvite() then
    local first, last, data = text:find("|Hplayer:([^|]+)|h.-|h")
    local sender = data and data:match("^([^:]+)")
    local channel = data and data:match("^[^:]+:%d+:([^:]+)")
    if first and validName(sender) and (not channel or INVITE_CHANNELS[channel]) then
      local prefix = text:sub(1, first - 1):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      prefix = prefix:gsub("|Hchannel:[^|]*|h.-|h", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("%b[]", ""):gsub("%[", "")
      local badge = text:sub(last + 1):match("^ |A:friendslist%-recentallies%-yellow:[%d:%-]+|a")
      local headerStart = last + (badge and #badge or 0)
      local headerEnd = text:find(":", headerStart + 1, true)
      -- Only a native chat header may supply the sender; pasted player links do not.
      if prefix:match("^%s*$") and headerEnd then
        local header = text:sub(headerStart + 1, headerEnd - 1):gsub("|r", ""):gsub("|c%x%x%x%x%x%x%x%x", "")
        if header:match("^[%s%a\128-\255%]]*$") and (channel or header:match("^[%s%]]*$")) then
          text = text:sub(1, headerEnd)..formatInvites(text:sub(headerEnd + 1), sender)
        end
      end
    end
  end
  return text
end

function ChatLinks:HandleClick(link, button)
  if _G.canaccessvalue and not _G.canaccessvalue(link) then return false end
  if type(link) ~= "string" then return false end
  local url = link:match("^glassyurl:(.+)$")
  if not url and Core.db.profile.chatUrls and not Core:IsPratModuleEnabled("UrlCopy") then
    url = link:match("^url:(.+)$")
  end
  if url then
    if Core.db.profile.chatUrls and button == "LeftButton" and not url:find("|", 1, true) then
      Core:GetModule("ChatCopy"):ShowText(Core:Localize("Glassy: Copy URL"), url)
    end
    return true
  end
  local invite = link:match("^glassyinvite:(.+)$")
  if not invite and Core.db.profile.chatInvites and not Core:IsPratModuleEnabled("Invites") then
    invite = link:match("^invplr:(.+)$")
  end
  local player = link:match("^player:([^:]+)")
  if invite or (player and button == "LeftButton" and _G.IsAltKeyDown and _G.IsAltKeyDown()) then
    if Core.db.profile.chatInvites and not Core:IsPratModuleEnabled("Invites") and button == "LeftButton"
      and validName(invite or player) and canInvite() then
      local inviteUnit = _G.InviteUnit or (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit)
      if inviteUnit then inviteUnit(invite or player) end
      return true
    end
    return invite ~= nil
  end
  return false
end
