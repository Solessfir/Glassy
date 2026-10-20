local Core = unpack(select(2, ...))
local Demo = Core:GetModule("Demo")

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
-- luacheck: pop

local DEMO_INTERVAL = 2.5

local function sample(text, r, g, b)
  return {"|cffdfba69[Demo]|r " .. text, r, g, b}
end

local samples = {
  sample("[Guild] |cff3fc7eb[Elowen]|r: Anyone up for a dungeon?", 0.25, 1, 0.25),
  sample("[Guild] |cfff48cba[Brenna]|r: Sure, I can heal. Just finishing this quest.", 0.25, 1, 0.25),
  sample("You receive loot: |cffffffff|Hitem:2589|h[Linen Cloth]|h|r x4.", 0, 0.67, 0),
  sample("You loot 12 |TInterface\\MoneyFrame\\UI-SilverIcon:12|t " ..
    "45 |TInterface\\MoneyFrame\\UI-CopperIcon:12|t", 1, 1, 0),
  sample("[Party] |cffc69b6d[Torin]|r: Everyone ready?", 0.67, 0.67, 1),
  sample("[Party] |cffaad372[Rowan]|r: Ready!", 0.67, 0.67, 1),
  sample("|cfffff468[Mira]|r whispers: I'm near the flight master. Let me know when you're back in town.", 1, 0.5, 1),
  sample("You receive loot: |cff1eff00|Hitem:15210|h[Raider's Shortsword]|h|r.", 0, 0.67, 0),
  sample("[Party] |cfff48cba[Brenna]|r: Give me a moment to drink before the next pull.", 0.67, 0.67, 1),
  sample("Quest accepted: A Helping Hand", 1, 1, 0),
  sample("[1. General] |cff3fc7eb[Elowen]|r: " ..
    "The entrance is around the back of the tower, past the bridge.", 1, 0.75, 0.75),
  sample("You receive loot: |cffffffff|Hitem:2447|h[Peacebloom]|h|r x2.", 0, 0.67, 0),
  sample("[Party] |cffc69b6d[Torin]|r: Let's clear the patrol first, then head up the stairs together. " ..
    "There is another group just around the corner, so stay close to the wall until everyone is ready.", 0.67, 0.67, 1),
  sample("You gain 250 reputation with Stormwind.", 0.5, 0.5, 1),
  sample("[Guild] |cffaad372[Rowan]|r: That was a great run. Same time tomorrow?", 0.25, 1, 0.25),
  sample("|cfffff468[Mira]|r has come online.", 1, 1, 0),
  sample("You receive loot: |cff0070dd|Hitem:2042|h[Staff of Westfall]|h|r.", 0, 0.67, 0),
  sample("[Party] |cfff48cba[Brenna]|r: Nice! Congratulations!", 0.67, 0.67, 1),
  sample("A Helping Hand completed.", 1, 1, 0),
  sample("[Guild] |cff3fc7eb[Elowen]|r: " ..
    "Thanks everyone. I'll put the spare materials in the guild bank.", 0.25, 1, 0.25),
}

local function eachMessageFrame(callback)
  for _, window in pairs(Core:GetModule("UIManager").state.windows) do
    local frame = window.active and window.slidingMessageFrame
    if frame and frame.state and not frame.state.isCombatLog then
      callback(frame)
    end
  end
end

function Demo:OnInitialize()
  self.active = false
  self.cursor = 0
end

function Demo:IsActive()
  return self.active
end

function Demo:AddNextMessage()
  self.cursor = self.cursor % #samples + 1
  local message = samples[self.cursor]
  eachMessageFrame(function (frame)
    frame:AddDemoMessage(unpack(message))
  end)
end

-- Real chat keeps recording into Blizzard's history and is restored when the demo ends.
function Demo:SetActive(active)
  active = active == true
  if self.active == active then return end
  self.active = active

  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end
  eachMessageFrame(function (frame)
    frame:SetDemoMode(active)
  end)

  if active then
    self.cursor = 0
    for _ = 1, #samples do
      self:AddNextMessage()
    end
    self.ticker = C_Timer.NewTicker(DEMO_INTERVAL, function ()
      self:AddNextMessage()
    end)
  end

  _G.LibStub("AceConfigRegistry-3.0"):NotifyChange("Glassy")
end
