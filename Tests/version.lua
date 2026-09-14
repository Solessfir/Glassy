local function loadVersion(modernVersion, legacyVersion)
  local addon = {}
  function addon:NewModule()
    return {}
  end

  local aceAddon = {}
  function aceAddon:NewAddon()
    return addon
  end

  LibStub = function(name)
    return name == "AceAddon-3.0" and aceAddon or {}
  end
  C_AddOns = modernVersion and {
    GetAddOnMetadata = function(addonName, field)
      assert(addonName == "Glassy" and field == "Version")
      return modernVersion
    end,
  } or nil
  GetAddOnMetadata = legacyVersion and function(addonName, field)
    assert(addonName == "Glassy" and field == "Version")
    return legacyVersion
  end or nil

  assert(loadfile("Glassy/init.lua"))("Glassy", {})
  return addon.Version
end

assert(loadVersion("2.3.4", "1.0.0") == "2.3.4", "Modern metadata API must take priority")
assert(loadVersion(nil, "3.4.5") == "3.4.5", "Legacy clients must use GetAddOnMetadata")
assert(loadVersion(nil, nil) == "0.0.0", "Missing metadata must have a safe fallback")

print("PASS: runtime version comes from modern and legacy TOC metadata APIs")
