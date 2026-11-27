local Core, Constants, Utils = unpack(select(2, ...))
local Aliases = Core:GetModule("SlashAliases")

local function notify(message)
  Utils.notify((message:gsub("|", "||")))
end

local function splitCommand(text)
  local name, arguments = text:match("^%s*/?(%S+)%s*(.*)$")
  if name and name:match("^[%w_%-]+$") then return name:lower(), arguments end
end

local function slashHandler(name)
  local slash = "/"..name:upper()
  local handler = _G.hash_SlashCmdList and _G.hash_SlashCmdList[slash]
  if handler then return handler end
  for key, callback in pairs(_G.SlashCmdList) do
    local index = 1
    while _G["SLASH_"..key..index] do
      if _G["SLASH_"..key..index]:upper() == slash then return callback end
      index = index + 1
    end
  end
end

local function isProtected(name)
  return _G.IsSecureCmd and (_G.IsSecureCmd(name) or _G.IsSecureCmd("/"..name))
end

local function isTaken(name)
  return slashHandler(name) or isProtected(name) or
    (_G.hash_ChatTypeInfoList and _G.hash_ChatTypeInfoList["/"..name:upper()])
end

local function canRun(name)
  return (name == "reload" and type(_G.ReloadUI) == "function") or (not isProtected(name) and slashHandler(name))
end

function Aliases:Run(name, input, editBox)
  local expansion = Core.db.global.slashAliases[name]
  if type(expansion) ~= "string" then return end
  local inLockdown = _G.C_ChatInfo and _G.C_ChatInfo.InChatMessagingLockdown
  if type(inLockdown) == "function" and inLockdown() then
    notify(Core:Localize("Aliases are unavailable during chat messaging lockdown."))
    return
  end
  if _G.canaccessvalue and not _G.canaccessvalue(input) then return end
  local target, arguments = splitCommand(expansion)
  if not target or self.registered[target] or not canRun(target) then
    notify(Core:Localize("Alias target is unavailable.").." "..expansion)
    return
  end
  if target == "reload" and type(_G.ReloadUI) == "function" then
    _G.ReloadUI()
    return
  end
  local handler = slashHandler(target)
  if arguments ~= "" and input ~= "" then arguments = arguments.." " end
  handler(arguments..input, editBox)
end

function Aliases:Register(name)
  if self.registered[name] then return true end
  if isTaken(name) then return false end
  local key = "GLASSYALIAS_"..name:upper()
  _G["SLASH_"..key.."1"] = "/"..name
  local callback = function (input, editBox) self:Run(name, input or "", editBox) end
  _G.SlashCmdList[key] = callback
  self.registered[name] = callback
  return true
end

function Aliases:Unregister(name)
  local callback = self.registered[name]
  if not callback then return end
  local key = "GLASSYALIAS_"..name:upper()
  _G["SLASH_"..key.."1"] = nil
  _G.SlashCmdList[key] = nil
  local slash = "/"..name:upper()
  if _G.hash_SlashCmdList and _G.hash_SlashCmdList[slash] == callback then
    _G.hash_SlashCmdList[slash] = nil
    if _G.hash_ChatTypeInfoList and _G.hash_ChatTypeInfoList[slash] == key then
      _G.hash_ChatTypeInfoList[slash] = nil
    end
  end
  self.registered[name] = nil
end

function Aliases:ParseDefinition(input)
  if _G.canaccessvalue and not _G.canaccessvalue(input) then return end
  if not Core.db.profile.slashAliasesEnabled then
    return nil, Core:Localize("Slash aliases are disabled in Glassy settings.")
  end
  if type(input) ~= "string" then return end
  local name, expansion = input:match("^%s*/?([%w_%-]+)[%s=]+(/%S.-)%s*$")
  local target = expansion and splitCommand(expansion)
  if not target then
    return nil, Core:Localize("Enter an alias such as /rld = /reload.")
  end
  name = name:lower()
  if name == target or self.registered[target] or not canRun(target) then
    return nil, Core:Localize("Alias target is unavailable.").." "..expansion
  end
  if not self.registered[name] and isTaken(name) then
    return nil, Core:Localize("That slash command is already in use.").." /"..name
  end
  return name, expansion
end

function Aliases:Set(input)
  local name, expansion = self:ParseDefinition(input)
  if not name then
    if expansion then notify(expansion) end
    return
  end
  if not self:Register(name) then
    notify(Core:Localize("That slash command is already in use.").." /"..name)
    return
  end
  Core.db.global.slashAliases[name] = expansion
  notify("/"..name.." -> "..expansion)
  Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
  return name
end

function Aliases:Remove(input)
  if _G.canaccessvalue and not _G.canaccessvalue(input) then return end
  local name, extra = splitCommand(input)
  if not name or extra ~= "" or not Core.db.global.slashAliases[name] then
    notify(Core:Localize("Usage: /unalias shortcut"))
    return
  end
  Core.db.global.slashAliases[name] = nil
  self:Unregister(name)
  notify(Core:Localize("Alias removed.").." /"..name)
  Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
end

function Aliases:List()
  local names = {}
  for name, expansion in pairs(Core.db.global.slashAliases) do
    if type(name) == "string" and type(expansion) == "string" then names[#names + 1] = name end
  end
  table.sort(names)
  if #names == 0 then notify(Core:Localize("No aliases saved.")) end
  for _, name in ipairs(names) do
    notify("/"..name.." -> "..Core.db.global.slashAliases[name])
  end
end

function Aliases:Refresh()
  local enabled = Core.db.profile.slashAliasesEnabled
  for name in pairs(self.registered) do
    if not enabled or not Core.db.global.slashAliases[name] then self:Unregister(name) end
  end
  if not enabled then return end
  for name, target in pairs(Core.db.global.slashAliases) do
    if type(name) == "string" and name:match("^[%w_%-]+$") and type(target) == "string" then
      self:Register(name)
    end
  end
end

function Aliases:OnEnable()
  self.registered = self.registered or {}
  for name, method in pairs({alias = "Set", unalias = "Remove", listaliases = "List"}) do
    if not isTaken(name) then self:RegisterChatCommand(name, method) end
  end
  if not self.subscribed then
    self.subscribed = true
    Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
      if key == "slashAliasesEnabled" and self:IsEnabled() then self:Refresh() end
    end)
  end
  self:Refresh()
end

function Aliases:OnDisable()
  for name in pairs(self.registered) do self:Unregister(name) end
end
