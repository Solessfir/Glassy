local Core, Constants, Utils = unpack(select(2, ...))

-- Retail must retain native methods used by the secure chat and Combat Log handlers.
function Utils.hookPresentation(owner, object, method, handler)
  if Constants.ENV ~= "retail" then
    owner:RawHook(object, method, handler, true)
    return
  end

  local original = object[method]
  local updating = false
  owner:SecureHook(object, method, function (...)
    if updating then return end
    updating = true
    local ok, err = pcall(handler, ...)
    updating = false
    if not ok then error(err, 0) end
  end)
  -- Existing styling callbacks use this reference to apply Glassy's final layout or color.
  owner.hooks[object][method] = original
end

-- Utility functions
-- Folds A-Z plus accented Latin and Cyrillic capitals, so case-insensitive matching works for European and
-- Russian text. Byte ranges rather than string.lower, which follows the C locale and can rewrite UTF-8 bytes.
-- Other scripts used by WoW clients have no case.
local LOWER_ASCII, LOWER_UTF8 = {}, {}
for byte = 0x41, 0x5A do LOWER_ASCII[string.char(byte)] = string.char(byte + 0x20) end
for byte = 0x80, 0x9E do
  if byte ~= 0x97 then LOWER_UTF8["\195"..string.char(byte)] = "\195"..string.char(byte + 0x20) end
end
for byte = 0x80, 0x8F do LOWER_UTF8["\208"..string.char(byte)] = "\209"..string.char(byte + 0x10) end
for byte = 0x90, 0x9F do LOWER_UTF8["\208"..string.char(byte)] = "\208"..string.char(byte + 0x20) end
for byte = 0xA0, 0xAF do LOWER_UTF8["\208"..string.char(byte)] = "\209"..string.char(byte - 0x20) end

function Utils.lower(text)
  return (text:gsub("[A-Z]", LOWER_ASCII):gsub("[\195\208][\128-\191]", LOWER_UTF8))
end

Utils.super = function (obj)
  return getmetatable(obj).__index
end

---
-- Print to VDT
Utils.print = function (str, t)
  if _G.ViragDevTool_AddData then
    _G.ViragDevTool_AddData(t, str)
  else
    -- Buffer print messages until ViragDevTool loads
    table.insert(Core.printBuffer, {str, t})
  end
end

---
-- Prints Glassy' notification messages
Utils.notify = function (message)
  print("|c00DFBA69Glassy|r: ", message)
end

local function parseVersion(version)
  if type(version) ~= "string" then
    return nil
  end

  local major, minor, patch, suffix = version:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
  if major == nil or (suffix ~= "" and suffix:sub(1, 1) ~= "-") then
    return nil
  end

  return {
    tonumber(major),
    tonumber(minor),
    tonumber(patch),
    prerelease = suffix ~= ""
  }
end

---
-- Returns true if version is newer
Utils.versionGreaterThan = function (current, previous)
  local cur = parseVersion(current)
  local prev = parseVersion(previous)

  if cur == nil or prev == nil then
    return tostring(current) ~= tostring(previous)
  end

  for index = 1, 3 do
    if cur[index] ~= prev[index] then
      return cur[index] > prev[index]
    end
  end

  -- A stable release is newer than a prerelease with the same numbers.
  return prev.prerelease and not cur.prerelease
end
