local Core = unpack(select(2, ...))
local ProfileTransfer = Core:GetModule("ProfileTransfer")

local PREFIX = "GLASSY1:"
local MAX_TEXT_LENGTH = 131072
local MAX_VALUES = 4096
local MAX_DEPTH = 12

function ProfileTransfer:NormalizeBackgroundFades(profile, defaults)
  local width = math.max(1, tonumber(profile.frameWidth) or defaults.frameWidth or 600)
  for _, side in ipairs({"Left", "Right"}) do
    local key = "backgroundFade"..side
    local pixels = tonumber(rawget(profile, key.."Width"))
    local legacy = rawget(profile, key)
    if pixels == nil and type(legacy) == "boolean" then
      pixels = legacy and (side == "Left" and 50 or 250) or 0
    end
    local percent = pixels and pixels / width * 100 or tonumber(profile[key.."Percent"])
    if percent ~= nil then
      profile[key.."Percent"] = math.max(0, math.min(100, percent))
    end
    profile[key.."Width"] = nil
    profile[key] = nil
  end
end

local function fail(message)
  error(message, 0)
end

local function sortedKeys(value)
  local keys = {}
  for key in pairs(value) do
    local keyType = type(key)
    if keyType ~= "number" and keyType ~= "string" then
      fail("unsupported table key")
    end
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    local leftType = type(left)
    local rightType = type(right)
    if leftType ~= rightType then
      return leftType < rightType
    end
    return left < right
  end)
  return keys
end

local function encodeValue(value, output, state, depth)
  if depth > MAX_DEPTH then
    fail("profile is too deeply nested")
  end
  state.values = state.values + 1
  if state.values > MAX_VALUES then
    fail("profile has too many values")
  end

  local valueType = type(value)
  if valueType == "boolean" then
    output[#output + 1] = value and "b1" or "b0"
  elseif valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      fail("invalid number")
    end
    local text = tostring(value)
    output[#output + 1] = "n"..#text..":"..text
  elseif valueType == "string" then
    state.bytes = state.bytes + #value
    if state.bytes > MAX_TEXT_LENGTH then
      fail("profile is too large")
    end
    output[#output + 1] = "s"..#value..":"..value
  elseif valueType == "table" then
    if state.tables[value] then
      fail("profile contains a table cycle")
    end
    state.tables[value] = true
    local keys = sortedKeys(value)
    output[#output + 1] = "t"..#keys..":"
    for _, key in ipairs(keys) do
      encodeValue(key, output, state, depth + 1)
      encodeValue(value[key], output, state, depth + 1)
    end
    state.tables[value] = nil
  else
    fail("unsupported value type")
  end
end

local function readLength(state)
  local colon = string.find(state.text, ":", state.position, true)
  if colon == nil then
    fail("missing value length")
  end
  local encoded = string.sub(state.text, state.position, colon - 1)
  if encoded == "" or string.find(encoded, "[^0-9]") then
    fail("invalid value length")
  end
  local length = tonumber(encoded)
  if length == nil or length > MAX_TEXT_LENGTH then
    fail("value is too large")
  end
  state.position = colon + 1
  return length
end

local function decodeValue(state, depth)
  if depth > MAX_DEPTH then
    fail("profile is too deeply nested")
  end
  state.values = state.values + 1
  if state.values > MAX_VALUES then
    fail("profile has too many values")
  end

  local tag = string.sub(state.text, state.position, state.position)
  state.position = state.position + 1
  if tag == "b" then
    local encoded = string.sub(state.text, state.position, state.position)
    state.position = state.position + 1
    if encoded == "1" then return true end
    if encoded == "0" then return false end
    fail("invalid boolean")
  elseif tag == "n" or tag == "s" then
    local length = readLength(state)
    local last = state.position + length - 1
    if last > #state.text then
      fail("truncated value")
    end
    local encoded = string.sub(state.text, state.position, last)
    state.position = last + 1
    if tag == "s" then
      return encoded
    end
    local number = tonumber(encoded)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
      fail("invalid number")
    end
    return number
  elseif tag == "t" then
    local count = readLength(state)
    if count > MAX_VALUES then
      fail("table has too many values")
    end
    local value = {}
    for _ = 1, count do
      local key = decodeValue(state, depth + 1)
      if type(key) ~= "number" and type(key) ~= "string" then
        fail("unsupported table key")
      end
      if value[key] ~= nil then
        fail("duplicate table key")
      end
      value[key] = decodeValue(state, depth + 1)
    end
    return value
  end
  fail("unknown value type")
end

local function sanitizeValue(value, default, depth)
  if depth > MAX_DEPTH or type(value) ~= type(default) then
    fail("setting type mismatch")
  end
  if type(default) ~= "table" then
    return value
  end

  local sanitized = {}
  local wildcard = rawget(default, "*")
  if wildcard ~= nil then
    for key, child in pairs(value) do
      if type(key) ~= "string" then
        fail("invalid setting key")
      end
      sanitized[key] = sanitizeValue(child, wildcard, depth + 1)
    end
  elseif next(default) == nil then
    local count = 0
    local highest = 0
    for key, child in pairs(value) do
      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(child) ~= "string" then
        fail("invalid setting list")
      end
      count = count + 1
      highest = math.max(highest, key)
      sanitized[key] = child
    end
    if highest ~= count then
      fail("invalid setting list")
    end
  else
    for key, child in pairs(value) do
      local childDefault = rawget(default, key)
      if childDefault ~= nil then
        sanitized[key] = sanitizeValue(child, childDefault, depth + 1)
      end
    end
  end
  return sanitized
end

function ProfileTransfer:Export(profile)
  if type(profile) ~= "table" then
    return nil, "profile must be a table"
  end
  local success, result = pcall(function ()
    local output = {PREFIX}
    encodeValue(profile, output, {bytes = 0, tables = {}, values = 0}, 1)
    local encoded = table.concat(output)
    if #encoded > MAX_TEXT_LENGTH then
      fail("profile is too large")
    end
    return encoded
  end)
  if success then
    return result
  end
  return nil, result
end

function ProfileTransfer:Import(text, defaults)
  if type(text) ~= "string" or type(defaults) ~= "table" or #text > MAX_TEXT_LENGTH then
    return nil, "invalid profile string"
  end
  local success, result = pcall(function ()
    local start = string.find(text, "%S") or 1
    if string.sub(text, start, start + #PREFIX - 1) ~= PREFIX then
      fail("invalid profile prefix")
    end
    local state = {position = start + #PREFIX, text = text, values = 0}
    local decoded = decodeValue(state, 1)
    if type(decoded) ~= "table" or not string.match(string.sub(text, state.position), "^%s*$") then
      fail("invalid profile data")
    end
    self:NormalizeBackgroundFades(decoded, defaults)
    local sanitized = sanitizeValue(decoded, defaults, 1)
    if next(sanitized) == nil then
      fail("profile has no supported settings")
    end
    return sanitized
  end)
  if success then
    return result
  end
  return nil, result
end
