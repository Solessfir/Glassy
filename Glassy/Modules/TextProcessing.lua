local _G = _G
local canaccessvalue = _G.canaccessvalue

local Core = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")

local EMOTE_PATH = "Interface\\AddOns\\Glassy\\Glassy\\Assets\\Emotes\\"
-- Faces render slightly taller than the message text.
local EMOTE_SCALE = 1.15

-- Smileys typed as their own word. A typed "|" arrives doubled because it starts WoW's text codes.
local SMILEYS = {
  [":)"] = "smile", [":-)"] = "smile",
  [":("] = "sad", [":-("] = "sad",
  [":D"] = "grin", [":-D"] = "grin",
  [";)"] = "wink", [";-)"] = "wink",
  [":P"] = "tongue", [":p"] = "tongue", [":-P"] = "tongue", [":-p"] = "tongue",
  [":O"] = "wow", [":o"] = "wow", [":-O"] = "wow", [":-o"] = "wow",
  [":||"] = "neutral", [":-||"] = "neutral",
  [":/"] = "meh", [":-/"] = "meh",
  ["xD"] = "laugh", ["XD"] = "laugh",
  ["<3"] = "heart",
  ["</3"] = "brokenheart",
  ["D:"] = "horror",
  [":S"] = "confused", [":s"] = "confused", [":-S"] = "confused", [":-s"] = "confused",
  [":*"] = "kiss", [":-*"] = "kiss",
  ["B)"] = "cool", ["B-)"] = "cool",
  [":'("] = "cry",
  [">:("] = "angry", [">:-("] = "angry",
  ["^^"] = "joy", ["^_^"] = "joy",
  ["-_-"] = "unamused",
  ["o.O"] = "wtf", ["O.o"] = "wtf",
  [":3"] = "cat",
  ["T_T"] = "sob",
  [":$"] = "blush",
}

-- Shortcodes such as :smile:, including the common names earlier versions accepted.
local SHORTCODES = {
  angry = "angry", blush = "blush", brokenheart = "brokenheart", broken_heart = "brokenheart", cat = "cat",
  confused = "confused", cool = "cool", sunglasses = "cool", cry = "cry", grin = "grin", heart = "heart",
  horror = "horror", scream = "horror", joy = "joy", kiss = "kiss", laugh = "laugh", meh = "meh",
  neutral = "neutral", rage = "angry", sad = "sad", slight_frown = "sad", smile = "smile", slight_smile = "smile",
  sob = "sob", tongue = "tongue", stuck_out_tongue = "tongue", stuck_out_tongue_closed_eyes = "tongue",
  unamused = "unamused", wink = "wink", wow = "wow", open_mouth = "wow", wtf = "wtf",
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

local emoteMarkupCache = {}

-- The Glassy set is drawn in white and tinted gold; the Classic set keeps its own colors.
local function getEmoteMarkup(name)
  local profile = Core.db.profile
  local style = profile.emoteStyle == "classic" and "classic" or "glass"
  local size = math.floor((tonumber(profile.messageFontSize) or 13) * EMOTE_SCALE + 0.5)
  local key = style..name..size
  if not emoteMarkupCache[key] then
    local tint = style == "glass" and ":223:186:105" or ""
    emoteMarkupCache[key] = "|T"..EMOTE_PATH..style.."_"..name..":"..size..":"..size..":0:0:32:32:0:32:0:32"..tint.."|t"
  end
  return emoteMarkupCache[key]
end

local function emoteWord(word)
  local name = SMILEYS[word]
  if name then return getEmoteMarkup(name) end
  -- Smileys that end a sentence, such as ":)." or "<3!!"
  local smiley, trail = word:match("^(.-)([%.,!%?]+)$")
  name = smiley and SMILEYS[smiley]
  if name then return getEmoteMarkup(name)..trail end
end

local function emoteSegment(segment)
  segment = segment:gsub(":([%l_]+):", function (shortcode)
    local name = SHORTCODES[shortcode]
    return name and getEmoteMarkup(name)
  end)
  return (segment:gsub("%S+", emoteWord))
end

-- Links, textures, atlases, and protected names keep their escape sequences untouched.
local PROTECTED_SEQUENCES = {"|H.-|h.-|h", "|T.-|t", "|A.-|a", "|K.-|k"}

local function findProtectedSequence(text, cursor)
  local firstStart, firstEnd
  for _, pattern in ipairs(PROTECTED_SEQUENCES) do
    local sequenceStart, sequenceEnd = strfind(text, pattern, cursor)
    if sequenceStart and (firstStart == nil or sequenceStart < firstStart) then
      firstStart, firstEnd = sequenceStart, sequenceEnd
    end
  end
  return firstStart, firstEnd
end

local function emojiProcessor(text)
  local parts = {}
  local cursor = 1
  while true do
    local sequenceStart, sequenceEnd = findProtectedSequence(text, cursor)
    if not sequenceStart then
      parts[#parts + 1] = emoteSegment(strsub(text, cursor))
      break
    end
    parts[#parts + 1] = emoteSegment(strsub(text, cursor, sequenceStart - 1))
    parts[#parts + 1] = strsub(text, sequenceStart, sequenceEnd)
    cursor = sequenceEnd + 1
  end
  return table.concat(parts)
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
