local Core = unpack(select(2, ...))
local WhisperTabs = Core:GetModule("WhisperTabs")

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
-- luacheck: pop

local SAVED_LINES = 100
-- Restore after the client has rebuilt its own chat windows.
local RESTORE_DELAY = 2

local function canAccess(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

-- Battle.net whisper targets change every session, so only character whispers are kept.
local function eachWhisperFrame(callback)
  for _, name in ipairs(_G.CHAT_FRAMES or {}) do
    local chatFrame = _G[name]
    local target = chatFrame and chatFrame.isTemporary and chatFrame.inUse and chatFrame.chatType == "WHISPER"
      and chatFrame.chatTarget
    if target and canAccess(target) and type(target) == "string" and target ~= "" then
      callback(chatFrame, target)
    end
  end
end

local function readLines(chatFrame)
  local lines = {}
  local count = chatFrame:GetNumMessages()
  for index = math.max(1, count - SAVED_LINES + 1), count do
    local text, red, green, blue = chatFrame:GetMessageInfo(index)
    if canAccess(text) and type(text) == "string" and text ~= "" then
      lines[#lines + 1] = {text, red, green, blue}
    end
  end
  return lines
end

function WhisperTabs:Save()
  local tabs = {}
  if Core.db.profile.keepWhisperTabs then
    eachWhisperFrame(function (chatFrame, target)
      tabs[#tabs + 1] = {target = target, lines = readLines(chatFrame)}
    end)
  end
  Core.db.char.whisperTabs = tabs
end

local function findWhisperFrame(target)
  local found
  eachWhisperFrame(function (chatFrame, frameTarget)
    if frameTarget:lower() == target:lower() then found = found or chatFrame end
  end)
  return found
end

function WhisperTabs:Restore()
  local tabs = Core.db.char.whisperTabs
  Core.db.char.whisperTabs = nil
  if not Core.db.profile.keepWhisperTabs or type(tabs) ~= "table" or not _G.FCF_OpenTemporaryWindow then return end

  for _, tab in ipairs(tabs) do
    if type(tab.target) == "string" then
      -- A whisper that arrived meanwhile already reopened the tab; older lines go above it.
      local chatFrame = findWhisperFrame(tab.target)
      if not chatFrame then
        local ok, opened = pcall(_G.FCF_OpenTemporaryWindow, "WHISPER", tab.target, nil, false)
        chatFrame = ok and opened or findWhisperFrame(tab.target)
      end
      if chatFrame and type(tab.lines) == "table" then
        for index = #tab.lines, 1, -1 do
          local line = tab.lines[index]
          chatFrame:BackFillMessage(line[1], line[2], line[3], line[4])
        end
      end
    end
  end
end

function WhisperTabs:OnEnable()
  -- AceDB fires this on logout and reload while the profile can still be read.
  Core.db.RegisterCallback(self, "OnDatabaseShutdown", function ()
    pcall(self.Save, self)
  end)
  C_Timer.After(RESTORE_DELAY, function ()
    self:Restore()
  end)
end
