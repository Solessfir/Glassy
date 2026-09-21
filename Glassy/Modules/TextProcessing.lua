local _G = _G
local canaccessvalue = _G.canaccessvalue

local Core = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

local EMOJI_MEDIA_KEYS = {
  angry = "Angry",
  blush = "Blush",
  broken_heart = "BrokenHeart",
  call_me = "CallMe",
  cry = "Cry",
  facepalm = "Facepalm",
  grin = "Grin",
  heart = "Heart",
  heart_eyes = "HeartEyes",
  joy = "Joy",
  kappa = "Kappa",
  meaw = "Meaw",
  middle_finger = "MiddleFinger",
  murloc = "Murloc",
  ok_hand = "OkHand",
  open_mouth = "OpenMouth",
  poop = "Poop",
  rage = "Rage",
  sadkitty = "SadKitty",
  scream = "Scream",
  scream_cat = "ScreamCat",
  semi_colon = "SemiColon",
  slight_frown = "SlightFrown",
  slight_smile = "SlightSmile",
  smile = "Smile",
  smirk = "Smirk",
  sob = "Sob",
  stuck_out_tongue = "StuckOutTongue",
  stuck_out_tongue_closed_eyes = "StuckOutTongueClosedEyes",
  sunglassyes = "Sunglassyes",
  thinking = "Thinking",
  thumbs_up = "ThumbsUp",
  wink = "Wink",
  zzz = "ZZZ",
}

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local strjoin = strjoin
local strsplit = strsplit
local strfind = strfind
local strlen = strlen
local strsub = strsub
local date = date
-- luacheck: pop

---
--Takes a texture escape string and adjusts its yOffset
local function adjustTextureYOffset(texture)
  -- Texture has 14 parts
  -- path, height, width, offsetX, offsetY,
  -- texWidth, texHeight
  -- leftTex, topTex, rightTex, bottomText,
  -- rColor, gColor, bColor

  -- Strip escape characters
  -- Split into parts
  local parts = {strsplit(':', strsub(texture, 3, -3))}
  local yOffset = Core.db.profile.iconTextureYOffset

  if #parts < 5 then
    -- Pad out ommitted attributes
    for i=1, 5 do
      if parts[i] == nil then
        if i == 3 then
          -- If width is not specified, the width should equal the height
          parts[i] = parts[2]
        else
          parts[i] = '0'
        end
      end
    end
  end

  -- Adjust yOffset by configured amount
  parts[5] = tostring((tonumber(parts[5]) or 0) - yOffset)

  -- Rejoin string and readd escape codes
  return '|T'..strjoin(':', unpack(parts))..'|t'
end


---
-- Gets all inline textures found in the string and adjusts their yOffset
local function textureProcessor(text)
  local cursor = 1
  local origLen = strlen(text)

  local parts = {}

  while cursor <= origLen do
    local mStart, mEnd = strfind(text, '%|T.-%|t', cursor)

    if mStart then
      table.insert(parts, strsub(text, cursor, mStart - 1))
      table.insert(parts, adjustTextureYOffset(strsub(text, mStart, mEnd)))
      cursor = mEnd + 1
    else
      -- No more matches
      table.insert(parts, strsub(text, cursor, origLen))
      cursor = origLen + 1
    end
  end

  return strjoin("", unpack(parts))
end

local function emojiProcessor(text)
  local elvui = rawget(_G, "ElvUI")
  local engine = type(elvui) == "table" and elvui[1]
  local media = engine and engine.Media
  local emojis = media and media.ChatEmojis
  if type(emojis) ~= "table" then
    return text
  end

  return text:gsub(":([%l_]+):", function (shortcode)
    local mediaKey = EMOJI_MEDIA_KEYS[shortcode]
    local texture = mediaKey and emojis[mediaKey]
    if type(texture) ~= "string" or texture == "" then
      return ":"..shortcode..":"
    end
    return "|T"..texture..":16:16|t"
  end)
end

local cachedTimestampRed
local cachedTimestampGreen
local cachedTimestampBlue
local cachedTimestampHex
local cachedBlacklistSource
local cachedBlacklistPhrases = {}

local function normalizeBlacklistText(text)
  text = text:gsub("|K.-|k", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|A.-|a", " ")
  text = text:gsub("|T.-|t", " ")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  text = text:gsub("||", "|")
  return text:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function getBlacklistPhrases()
  local source = Core.db.profile.messageBlacklist or ""
  if source == cachedBlacklistSource then
    return cachedBlacklistPhrases
  end

  cachedBlacklistSource = source
  cachedBlacklistPhrases = {}
  for line in source:gmatch("[^\r\n]+") do
    local phrase = normalizeBlacklistText(line)
    if phrase ~= "" then
      cachedBlacklistPhrases[#cachedBlacklistPhrases + 1] = phrase
    end
  end
  return cachedBlacklistPhrases
end

local function getTimestampColorHex(color)
  if (
    cachedTimestampHex and
    cachedTimestampRed == color.r and
    cachedTimestampGreen == color.g and
    cachedTimestampBlue == color.b
  ) then
    return cachedTimestampHex
  end

  local red = math.floor(math.max(0, math.min(1, color.r or 1)) * 255 + 0.5)
  local green = math.floor(math.max(0, math.min(1, color.g or 1)) * 255 + 0.5)
  local blue = math.floor(math.max(0, math.min(1, color.b or 1)) * 255 + 0.5)
  cachedTimestampRed = color.r
  cachedTimestampGreen = color.g
  cachedTimestampBlue = color.b
  cachedTimestampHex = string.format("%02x%02x%02x", red, green, blue)
  return cachedTimestampHex
end

local function timestampProcessor(text, frame, receivedAt)
  if type(text) ~= "string" then
    return text
  end

  local profile = Core.db.profile
  local frameName = frame and frame.GetName and frame:GetName()
  if (
    not profile.timestampsEnabled or
    not frameName or
    not profile.timestampFrames or
    not profile.timestampFrames[frameName]
  ) then
    return text
  end

  local timestamp = receivedAt and date(profile.timestampFormat, receivedAt) or date(profile.timestampFormat)
  if not profile.timestampColorEnabled then
    return timestamp.." "..text
  end
  return "|cff"..getTimestampColorHex(profile.timestampColor)..timestamp.."|r "..text
end

local function processSafely(processor, text, ...)
  local ok, result = pcall(processor, text, ...)
  if ok and type(result) == "string" then
    return result
  end

  return text
end

function TP:ProcessTextures(text)
  if canaccessvalue and not canaccessvalue(text) then return text end
  if type(text) ~= "string" or not strfind(text, "|T", 1, true) then
    return text
  end
  return processSafely(textureProcessor, text)
end

function TP:IsMessageBlacklisted(text)
  if not Core.db.profile.messageBlacklistEnabled then
    return false
  end
  if canaccessvalue and not canaccessvalue(text) then
    return false
  end
  if type(text) ~= "string" or text == "" then
    return false
  end

  local normalized = normalizeBlacklistText(text)
  for _, phrase in ipairs(getBlacklistPhrases()) do
    if normalized:find(phrase, 1, true) then
      return true
    end
  end
  return false
end

function TP:ProcessText(text, frame, receivedAt)
  -- Retail can supply protected text. Pass it directly to the native FontString without parsing it.
  if canaccessvalue and not canaccessvalue(text) then return text, text end
  local processedText = text
  if Core.db.profile.timestampsEnabled then
    processedText = processSafely(timestampProcessor, processedText, frame, receivedAt)
  end
  if Core.db.profile.emojisEnabled then
    processedText = processSafely(emojiProcessor, processedText)
  end
  return self:ProcessTextures(processedText), text
end
