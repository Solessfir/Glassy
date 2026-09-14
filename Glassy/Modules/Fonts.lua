local Core, Constants = unpack(select(2, ...))
local Fonts = Core:GetModule("Fonts")

local LSM = Core.Libs.LSM
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFont = CreateFont
-- luacheck: pop

local function setFont(fontObject, size)
  local fontPath = LSM:Fetch(LSM.MediaType.FONT, Core.db.profile.font, true) or DEFAULT_FONT_PATH
  local ok, applied = pcall(
    fontObject.SetFont,
    fontObject,
    fontPath,
    size,
    Core.db.profile.fontFlags
  )

  if not ok or applied == false then
    fontObject:SetFont(DEFAULT_FONT_PATH, size, Core.db.profile.fontFlags)
  end
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
  self.fonts.GlassyCombatLogNormalFont:SetTextColor(0.65, 0.65, 0.65)
  self.fonts.GlassyCombatLogNormalFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyCombatLogNormalFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogNormalFont:SetJustifyV("MIDDLE")

  self.fonts.GlassyCombatLogHighlightFont = CreateFont("GlassyCombatLogHighlightFont")
  setFont(self.fonts.GlassyCombatLogHighlightFont, 12)
  self.fonts.GlassyCombatLogHighlightFont:SetTextColor(
    Constants.COLORS.apache.r,
    Constants.COLORS.apache.g,
    Constants.COLORS.apache.b
  )
  self.fonts.GlassyCombatLogHighlightFont:SetShadowColor(0, 0, 0, 0)
  self.fonts.GlassyCombatLogHighlightFont:SetJustifyH("LEFT")
  self.fonts.GlassyCombatLogHighlightFont:SetJustifyV("MIDDLE")

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
    end

    if key == "font" or key == "editBoxFontSize" then
      setFont(self.fonts.GlassyEditBoxFont, Core.db.profile.editBoxFontSize)
    end
  end)
end
