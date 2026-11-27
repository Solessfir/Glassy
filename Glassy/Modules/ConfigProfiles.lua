local Core = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceDBOptions = Core.Libs.AceDBOptions
local ProfileTransfer = Core:GetModule("ProfileTransfer")
local L = function(text) return Core:Localize(text) end

local importedProfile
local importText = ""
local newProfileName = ""
local createProfileName = ""
local startFrom = ""

local PROFILE_OPTION_KEYS = {
  "current",
  "reset",
  "choose",
  "copyfrom",
  "delete",
}

local function copyTable(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = type(value) == "table" and copyTable(value) or value
  end
  return copy
end

local function mergeTable(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" and type(target[key]) == "table" then
      mergeTable(target[key], value)
    else
      target[key] = type(value) == "table" and copyTable(value) or value
    end
  end
end

local function trim(text)
  return string.match(text or "", "^%s*(.-)%s*$")
end

local function profileExists(name)
  local profiles = Core.db:GetProfiles()
  for _, profileName in ipairs(profiles) do
    if profileName == name then
      return true
    end
  end
  for _, profileName in pairs(Core.db.sv.profileKeys or {}) do
    if profileName == name then return true end
  end
  return false
end

local function profileLabels(excludeCurrent)
  local labels = {}
  for _, name in ipairs(Core.db:GetProfiles()) do
    if not excludeCurrent or name ~= Core.db:GetCurrentProfile() then
      labels[name] = name
    end
  end
  return labels
end

local function profileCharacters(name)
  local characters = {}
  for character, profileName in pairs(Core.db.sv.profileKeys or {}) do
    if profileName == name then characters[#characters + 1] = character end
  end
  table.sort(characters)
  if #characters == 0 then return L("No characters currently use this profile.") end
  return L("Characters using this profile").."\n"..table.concat(characters, "\n")
end

local function applyImportedProfile(profile)
  Core.db:ResetProfile(nil, true)
  mergeTable(Core.db.profile, profile)
  C:RefreshConfig()
end

local function getProfileOptions()
  local shared = AceDBOptions:GetOptionsTable(Core.db)
  local args = {}
  for _, key in ipairs(PROFILE_OPTION_KEYS) do
    if shared.args[key] then
      args[key] = copyTable(shared.args[key])
    end
  end
  args.current.order = 10
  local function validateNewName(_, value)
    local name = trim(value)
    if name == "" then return L("Enter a profile name.") end
    if not shared.args.new.validate(nil, name) then return shared.args.new.usage end
    if profileExists(name) then return L("A profile with that name already exists.") end
    return true
  end
  args.new = {
    name = "New profile",
    type = "group",
    inline = true,
    order = 20,
    args = {
      name = {
        name = "New profile name",
        desc = "Enter a unique name. Creating a profile keeps the source profile unchanged.",
        type = "input",
        order = 1,
        width = 1.4,
        get = function () return createProfileName end,
        validate = validateNewName,
        set = function (_, value) createProfileName = trim(value) end,
      },
      startFrom = {
        name = "Start from",
        desc = function ()
          local description = L("Copy Glassy settings into a separate profile. Chat history and native filters are unchanged. Tab order, selected tab, and per-tab timestamps start from defaults.")
          if startFrom ~= "" then return description.."\n\n"..profileCharacters(startFrom) end
          return description
        end,
        type = "select",
        order = 2,
        width = 1.8,
        values = function ()
          local values = profileLabels()
          values[""] = L("Defaults")
          return values
        end,
        get = function () return startFrom end,
        set = function (_, value) startFrom = value end,
      },
      create = {
        name = "Create and use profile",
        type = "execute",
        order = 3,
        width = 1.3,
        disabled = function ()
          return validateNewName(nil, createProfileName) ~= true or
            startFrom ~= "" and profileLabels()[startFrom] == nil
        end,
        func = function ()
          local name = trim(createProfileName)
          local valid = validateNewName(nil, name)
          if valid ~= true then C:Print(valid) return end
          local settings
          if startFrom ~= "" then
            if not profileLabels()[startFrom] then return end
            local source = startFrom == Core.db:GetCurrentProfile() and Core.db.profile or Core.db.profiles[startFrom]
            settings = copyTable(source)
            -- Native chat frame IDs can refer to different tabs on another character.
            settings.selectedTab, settings.tabOrder, settings.timestampFrames = nil, nil, nil
          end
          Core.db:SetProfile(name)
          if settings then
            mergeTable(Core.db.profile, settings)
            C:RefreshConfig()
          end
          createProfileName = ""
          startFrom = ""
          Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
        end,
      },
    },
  }
  args.reset.order = 1
  args.reset.confirm = function ()
    return string.format(L("Reset profile '%s'? All characters using it will lose its current settings."), Core.db:GetCurrentProfile())
  end
  args.choose.order = 15
  args.choose.name = "Use existing profile"
  args.choose.desc = function ()
    return L("Use an existing profile directly. Changes are shared with every character using that profile.").."\n\n"..profileCharacters(Core.db:GetCurrentProfile())
  end
  args.choose.values = function () return profileLabels() end
  args.choose.width = "full"
  args.copyfrom.order = 2
  args.copyfrom.name = "Replace current from"
  args.copyfrom.desc = "Overwrite the current profile with another profile's settings, affecting every character sharing the current profile."
  args.copyfrom.values = function () return profileLabels(true) end
  args.copyfrom.confirm = function (_, source)
    return string.format(L("Replace profile '%s' with settings from '%s'? All characters using the current profile will receive these settings."), Core.db:GetCurrentProfile(), source)
  end
  args.delete.order = 3
  args.delete.values = function () return profileLabels(true) end
  args.manage = {
    name = "Manage profiles",
    type = "group",
    inline = true,
    order = 40,
    args = {reset = args.reset, copyfrom = args.copyfrom, delete = args.delete},
  }
  args.reset, args.copyfrom, args.delete = nil, nil, nil
  args.transfer = {
    name = "Import and export",
    type = "group",
    inline = true,
    order = 30,
    args = {
      exportProfile = {
        name = "Export current profile",
        desc = "Create a copyable string containing only the current profile's settings.",
        type = "execute",
        order = 1,
        width = 1.4,
        func = function ()
          local encoded = ProfileTransfer:Export(Core.db.profile)
          if encoded == nil then
            C:Print(L("Could not export the current profile."))
            return
          end
          C:ShowCopyableText(L("Glassy: Export profile"), encoded)
        end,
      },
      importText = {
        name = "Profile string",
        desc = "Paste a Glassy profile export. The data is validated before it can be imported.",
        type = "input",
        order = 10,
        multiline = 6,
        width = "full",
        get = function () return importText end,
        validate = function (_, value)
          if trim(value) == "" then
            return true
          end
          return ProfileTransfer:Import(value, Core.defaults.profile) and true or L("Invalid Glassy profile string.")
        end,
        set = function (_, value)
          importText = value
          importedProfile = trim(value) ~= "" and ProfileTransfer:Import(value, Core.defaults.profile) or nil
        end,
      },
      newProfileName = {
        name = "New profile name",
        desc = "Enter a unique name for the imported profile.",
        type = "input",
        order = 20,
        width = 1.4,
        get = function () return newProfileName end,
        validate = validateNewName,
        set = function (_, value) newProfileName = value end,
      },
      importNew = {
        name = "Import as new",
        desc = "Create and select a new profile using the imported settings.",
        type = "execute",
        order = 21,
        width = 1.1,
        disabled = function ()
          return importedProfile == nil or validateNewName(nil, newProfileName) ~= true
        end,
        func = function ()
          local name = trim(newProfileName)
          local reason = validateNewName(nil, name)
          if reason ~= true then
            C:Print(reason)
            return
          end
          Core.db:SetProfile(name)
          applyImportedProfile(importedProfile)
          newProfileName = ""
          C:Print(string.format(L("Imported profile: %s"), name))
        end,
      },
      replaceProfile = {
        name = "Replace current",
        desc = "Replace the current profile with the imported settings.",
        type = "execute",
        order = 22,
        width = 1.2,
        disabled = function () return importedProfile == nil end,
        confirm = function ()
          return string.format(
            L("Replace profile '%s'? All characters using it will receive the imported settings."),
            Core.db:GetCurrentProfile()
          )
        end,
        func = function ()
          local name = Core.db:GetCurrentProfile()
          applyImportedProfile(importedProfile)
          C:Print(string.format(L("Imported profile: %s"), name))
        end,
      },
    },
  }

  return {
    type = shared.type,
    name = shared.name,
    desc = shared.desc,
    handler = shared.handler,
    args = args,
  }
end


C.Pages.profile = getProfileOptions
