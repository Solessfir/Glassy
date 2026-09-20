local Core, Constants = unpack(select(2, ...))
local Fonts = Core:GetModule("Fonts")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFont = CreateFont
local GameFontNormal = GameFontNormal
-- luacheck: pop

local function setFont(fontObject, size, setting)
  local defaultFontPath = GameFontNormal and GameFontNormal:GetFont()
  local selected = setting and Core.db.profile[setting]
  if not selected or selected == "" then selected = Core.db.profile.font end
  local flags = setting and Core.db.profile[setting.."Flags"]
  if not flags or flags == "INHERIT" then flags = "" end
  local shadow = false
  if flags and flags:sub(1, 6) == "SHADOW" then
    shadow = true
    flags = flags:sub(7)
  end
  local fontPath = LSM:Fetch(LSM.MediaType.FONT, selected, true) or defaultFontPath
  if fontPath == nil then
    return
  end
  local ok, applied = pcall(
    fontObject.SetFont,
    fontObject,
    fontPath,
    size,
    flags
  )

  if (not ok or applied == false) and defaultFontPath then
    fontObject:SetFont(defaultFontPath, size, flags)
  end
  fontObject:SetShadowColor(0, 0, 0, shadow and 1 or 0)
  fontObject:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
end

local function setCombatLogHighlightColor(fontObject)
  local color = Core.db.profile.tabHighlightTextColor or Constants.COLORS.apache
  fontObject:SetTextColor(
    color.r,
    color.g,
    color.b,
    1
  )
end

function Fonts:OnInitialize()
  self.fonts = {}
end

function Fonts:OnEnable()
  -- GlassyMessageFont
  self.fonts.GlassyMessageFont = CreateFont("GlassyMessageFont")
  setFont(self.fonts.GlassyMessageFont, Core.db.profile.messageFontSize, "messageFont")
  self.fonts.GlassyMessageFont:SetJustifyH("LEFT")
  self.fonts.GlassyMessageFont:SetJustifyV("MIDDLE")
  self.fonts.GlassyMessageFont:SetSpacing(Core.db.profile.messageLeading)

  -- GlassyChatDockFont
  self.fonts.GlassyChatDockFont = CreateFont("GlassyChatDockFont")
  setFont(self.fonts.GlassyChatDockFont, Core.db.profile.tabFontSize, "tabFont")
  self.fonts.GlassyChatDockFont:SetJustifyH("LEFT")
  self.fonts.GlassyChatDockFont:SetJustifyV("MIDDLE")
  self.fonts.GlassyChatDockFont:SetSpacing(3)

  -- Combat Log filter buttons
  self.fonts.GlassyCombatLogNormalFont = CreateFont("GlassyCombatLogNormalFont")
  setFont(self.fonts.GlassyCombatLogNormalFont, Core.db.profile.tabFontSize, "tabFont")
  local combatLogColor = Core.db.profile.tabTextColor
  self.fonts.GlassyCombatLogNormalFont:SetTextColor(combatLogColor.r, combatLogColor.g, combatLogColor.b, 1)
  self.fonts.GlassyCombatLogNormalFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogNormalFont:SetJustifyV("MIDDLE")

  self.fonts.GlassyCombatLogHighlightFont = CreateFont("GlassyCombatLogHighlightFont")
  setFont(self.fonts.GlassyCombatLogHighlightFont, Core.db.profile.tabFontSize, "tabFont")
  setCombatLogHighlightColor(self.fonts.GlassyCombatLogHighlightFont)
  self.fonts.GlassyCombatLogHighlightFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogHighlightFont:SetJustifyV("MIDDLE")

  self.fonts.GlassyCombatLogActiveFont = CreateFont("GlassyCombatLogActiveFont")
  setFont(self.fonts.GlassyCombatLogActiveFont, Core.db.profile.tabFontSize, "tabFont")
  setCombatLogHighlightColor(self.fonts.GlassyCombatLogActiveFont)
  self.fonts.GlassyCombatLogActiveFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogActiveFont:SetJustifyV("MIDDLE")

  -- GlassyEditBoxFont
  self.fonts.GlassyEditBoxFont = CreateFont("GlassyEditBoxFont")
  setFont(self.fonts.GlassyEditBoxFont, Core.db.profile.editBoxFontSize, "editBoxFont")
  self.fonts.GlassyEditBoxFont:SetJustifyH("LEFT")
  self.fonts.GlassyEditBoxFont:SetJustifyV("MIDDLE")
  self.fonts.GlassyEditBoxFont:SetSpacing(3)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "messageFontSize" then
      setFont(self.fonts.GlassyMessageFont, Core.db.profile.messageFontSize, "messageFont")
    end

    if key == "messageLeading" then
      self.fonts.GlassyMessageFont:SetSpacing(Core.db.profile.messageLeading)
    end

    if key == "font" or key == "tabFontSize" then
      setFont(self.fonts.GlassyChatDockFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.GlassyCombatLogNormalFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.GlassyCombatLogHighlightFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.GlassyCombatLogActiveFont, Core.db.profile.tabFontSize, "tabFont")
    end

    if key == "tabTextColor" then
      local color = Core.db.profile.tabTextColor
      self.fonts.GlassyCombatLogNormalFont:SetTextColor(color.r, color.g, color.b, 1)
    end

    if key == "tabHighlightTextColor" then
      setCombatLogHighlightColor(self.fonts.GlassyCombatLogActiveFont)
    end

    if key == "tabHighlightTextColor" then
      setCombatLogHighlightColor(self.fonts.GlassyCombatLogHighlightFont)
    end

    if key == "font" or key == "editBoxFontSize" then
      setFont(self.fonts.GlassyEditBoxFont, Core.db.profile.editBoxFontSize, "editBoxFont")
    end
  end)
end
