unpack = unpack or table.unpack

local function loadLocale(locale)
  local core = {}
  local addonVars = {[1] = core}
  local previousGetLocale = _G.GetLocale
  _G.GetLocale = function() return locale end

  assert(loadfile("Glassy/Localization.lua"))("Glassy", addonVars)
  local localeFiles = {
    deDE = "deDE", esES = "esES", esMX = "esES", frFR = "frFR",
    itIT = "itIT", koKR = "koKR", ptBR = "ptBR", ruRU = "ruRU",
    zhCN = "zhCN", zhTW = "zhTW",
  }
  if localeFiles[locale] then
    assert(loadfile("Glassy/Locales/" .. localeFiles[locale] .. ".lua"))("Glassy", addonVars)
  end

  _G.GetLocale = previousGetLocale
  return core
end

local english = loadLocale("enUS")
assert(english:Localize("General") == "General")
local translated, total = english:GetLocalizationCoverage()
assert(translated == 0 and total > 150)

local russian = loadLocale("ruRU")
translated, total = russian:GetLocalizationCoverage()
assert(translated == total, "Russian locale must translate every registered string")
assert(russian:Localize("General") == "Общие")
assert(russian:Localize("Version:") == "Версия:")
assert(russian:Localize("|cff80ff80Detected:|r Prat") == "|cff80ff80Обнаружен:|r Prat")

for _, locale in ipairs({"deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW"}) do
  local localized = loadLocale(locale)
  translated, total = localized:GetLocalizationCoverage()
  assert(translated == total, locale .. " must translate every registered string")
  assert(localized:Localize("General") ~= "General" or locale == "esES" or locale == "esMX")
  assert(localized:Localize("Prat Timestamps") == "Prat Timestamps", locale .. " must preserve the Prat module name")
  assert(localized:Localize("Prat History") == "Prat History", locale .. " must preserve the Prat module name")
  for _, label in ipairs({"Button hover color", "Inbox button color", "Saved aliases", "Chat alerts and sounds",
    "Chat rules", "Chat utilities"}) do
    assert(localized:Localize(label) ~= label, locale .. " must translate " .. label)
  end
  local aliasHint = "Format: /shortcut = /command. Example: /rld = /reload"
  local localizedHint = localized:Localize(aliasHint)
  assert(localizedHint ~= aliasHint and localizedHint:find("/rld = /reload", 1, true),
    locale .. " must translate the alias hint without changing the command")
end

local options = {
  name = "General",
  desc = function() return "Open settings" end,
  args = {
    child = {name = "Font", desc = "Font outline"},
    prat = {
      name = function() return russian:Localize("Fading")..": Fading, Font, Frames" end,
      nameLocalized = true,
    },
  },
}
russian:LocalizeOptions(options)
assert(options.name == "Общие")
assert(options.desc() == "Открыть настройки")
assert(options.args.child.name == "Шрифт")
assert(options.args.child.desc == "Контур шрифта")
assert(options.args.prat.name() == "Затухание: Fading, Font, Frames")
assert(options.args.prat.nameLocalized == nil, "Internal localization markers must not reach AceConfig")

print("PASS: fallback, complete locale catalogs, dynamic options, and formatted text")
