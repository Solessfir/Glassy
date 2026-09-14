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
