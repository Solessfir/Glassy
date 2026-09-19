local Core = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceDBOptions = Core.Libs.AceDBOptions
local ProfileTransfer = Core:GetModule("ProfileTransfer")
local L = function(text) return Core:Localize(text) end

local importedProfile
local importText = ""
local newProfileName = ""

local PROFILE_OPTION_KEYS = {
  "current",
  "new",
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
  return false
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
  args.new.order = 20
  args.reset.order = 30
  args.choose.order = 40
  args.copyfrom.order = 50
  args.delete.order = 60
  args.currentNewSpacer = {
    name = "",
    type = "description",
    order = 15,
    width = 0.1,
  }
  args.newResetSpacer = {
    name = "",
    type = "description",
    order = 25,
    width = 0.08,
  }
  args.profileRowsSpacer = {
    name = " ",
    type = "description",
    order = 35,
    width = "full",
  }
  args.chooseCopySpacer = {
    name = "",
    type = "description",
    order = 45,
    width = 0.1,
  }
  args.copyDeleteSpacer = {
    name = "",
    type = "description",
    order = 55,
    width = 0.1,
  }
  args.transfer = {
    name = "Import and export",
    type = "group",
    inline = true,
    order = 70,
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
        set = function (_, value) newProfileName = value end,
      },
      importNew = {
        name = "Import as new",
        desc = "Create and select a new profile using the imported settings.",
        type = "execute",
        order = 21,
        width = 1.1,
        disabled = function ()
          local name = trim(newProfileName)
          return importedProfile == nil or name == "" or profileExists(name)
        end,
        func = function ()
          local name = trim(newProfileName)
          if name == "" then
            C:Print(L("Enter a profile name."))
            return
          end
          if profileExists(name) then
            C:Print(L("A profile with that name already exists."))
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
            L("Replace profile '%s'? Its current settings will be lost."),
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
