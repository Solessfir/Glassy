local Core, Constants = unpack(select(2, ...))
local Fonts = Core:GetModule("Fonts")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFont = CreateFont
local GameFontNormal = GameFontNormal
-- luacheck: pop

local function setFont(fontObject, size)
  local defaultFontPath = GameFontNormal and GameFontNormal:GetFont()
  local fontPath = LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.font, true) or defaultFontPath
  if fontPath == nil then
    return
  end
  local ok, applied = pcall(
    fontObject.SetFont,
    fontObject,
    fontPath,
    size,
    Core.db.profile.fontFlags
  )

  if (not ok or applied == false) and defaultFontPath then
    fontObject:SetFont(defaultFontPath, size, Core.db.profile.fontFlags)
  end
end

local function setCombatLogHighlightColor(fontObject, setting)
  local strength = setting and math.max(0, math.min(1, tonumber(Core.db.profile[setting]) or 0)) or 0
  local brightness = 1 + strength
  local color = Core.db.profile.tabHighlightTextColor or Constants.COLORS.apache
  fontObject:SetTextColor(
    math.min(1, color.r * brightness),
    math.min(1, color.g * brightness),
    math.min(1, color.b * brightness),
    1
  )
end

function Fonts:OnInitialize()
  self.fonts = {}
end

function Fonts:OnEnable()
  -- GlassyMessageFont
  self.fonts.GlassyMessageFont = CreateFont("GlassyMessageFont")
  setFont(self.fonts.GlassyMessageFont, Core.db.profile.messageFontSize)
  self.fonts.GlassyMessageFont:SetShadowColor(0, 0, 0, 1)
  self.fonts.GlassyMessageFont:SetShadowOffset(1, -1)
  self.fonts.GlassyMessageFont:SetJustifyH("LEFT")
  self.fonts.GlassyMessageFont:SetJustifyV("MIDDLE")
  self.fonts.GlassyMessageFont:SetSpacing(Core.db.profile.messageLeading)

  -- GlassyChatDockFont
  self.fonts.GlassyChatDockFont = CreateFont("GlassyChatDockFont")
  setFont(self.fonts.GlassyChatDockFont, 12)
  self.fonts.GlassyChatDockFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyChatDockFont:SetShadowOffset(1, -1)
  self.fonts.GlassyChatDockFont:SetJustifyH("LEFT")
  self.fonts.GlassyChatDockFont:SetJustifyV("MIDDLE")
  self.fonts.GlassyChatDockFont:SetSpacing(3)

  -- Combat Log filter buttons
  self.fonts.GlassyCombatLogNormalFont = CreateFont("GlassyCombatLogNormalFont")
  setFont(self.fonts.GlassyCombatLogNormalFont, 12)
  local combatLogColor = Core.db.profile.tabTextColor
  self.fonts.GlassyCombatLogNormalFont:SetTextColor(combatLogColor.r, combatLogColor.g, combatLogColor.b, 1)
  self.fonts.GlassyCombatLogNormalFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyCombatLogNormalFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogNormalFont:SetJustifyV("MIDDLE")

  self.fonts.GlassyCombatLogHighlightFont = CreateFont("GlassyCombatLogHighlightFont")
  setFont(self.fonts.GlassyCombatLogHighlightFont, 12)
  setCombatLogHighlightColor(self.fonts.GlassyCombatLogHighlightFont, "hoverHighlightStrength")
  self.fonts.GlassyCombatLogHighlightFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyCombatLogHighlightFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogHighlightFont:SetJustifyV("MIDDLE")

  self.fonts.GlassyCombatLogActiveFont = CreateFont("GlassyCombatLogActiveFont")
  setFont(self.fonts.GlassyCombatLogActiveFont, 12)
  setCombatLogHighlightColor(self.fonts.GlassyCombatLogActiveFont)
  self.fonts.GlassyCombatLogActiveFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyCombatLogActiveFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogActiveFont:SetJustifyV("MIDDLE")

  -- GlassyEditBoxFont
  self.fonts.GlassyEditBoxFont = CreateFont("GlassyEditBoxFont")
  setFont(self.fonts.GlassyEditBoxFont, Core.db.profile.editBoxFontSize)
  self.fonts.GlassyEditBoxFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyEditBoxFont:SetShadowOffset(1, -1)
  self.fonts.GlassyEditBoxFont:SetJustifyH("LEFT")
  self.fonts.GlassyEditBoxFont:SetJustifyV("MIDDLE")
  self.fonts.GlassyEditBoxFont:SetSpacing(3)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "messageFontSize" then
      setFont(self.fonts.GlassyMessageFont, Core.db.profile.messageFontSize)
    end

    if key == "messageLeading" then
      self.fonts.GlassyMessageFont:SetSpacing(Core.db.profile.messageLeading)
    end

    if key == "font" then
      setFont(self.fonts.GlassyChatDockFont, 12)
      setFont(self.fonts.GlassyCombatLogNormalFont, 12)
      setFont(self.fonts.GlassyCombatLogHighlightFont, 12)
      setFont(self.fonts.GlassyCombatLogActiveFont, 12)
    end

    if key == "tabTextColor" then
      local color = Core.db.profile.tabTextColor
      self.fonts.GlassyCombatLogNormalFont:SetTextColor(color.r, color.g, color.b, 1)
    end

    if key == "tabHighlightTextColor" then
      setCombatLogHighlightColor(self.fonts.GlassyCombatLogActiveFont)
    end

    if key == "hoverHighlightStrength" or key == "tabHighlightTextColor" then
      setCombatLogHighlightColor(self.fonts.GlassyCombatLogHighlightFont, "hoverHighlightStrength")
    end

    if key == "font" or key == "editBoxFontSize" then
      setFont(self.fonts.GlassyEditBoxFont, Core.db.profile.editBoxFontSize)
    end
  end)
end
