local Core, Constants = unpack(select(2, ...))
local Fonts = Core:GetModule("Fonts")

local LSM = Core.Libs.LSM

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFont = CreateFont
local CreateFontFamily = CreateFontFamily
local ChatFontNormal = ChatFontNormal
local GameFontNormal = GameFontNormal
-- luacheck: pop

-- Custom fonts usually lack CJK and Cyrillic glyphs, so only the roman member uses the
-- selected font while the other alphabets keep the client's native chat fonts.
local ALPHABETS = {"roman", "korean", "simplifiedchinese", "traditionalchinese", "russian"}
local nativeMembers
local nativeFontPaths = {}

local function initNativeFonts()
  if nativeMembers ~= nil then return end
  nativeMembers = false
  if not CreateFontFamily or not ChatFontNormal or not ChatFontNormal.GetFontObjectForAlphabet then return end
  local members = {}
  for _, alphabet in ipairs(ALPHABETS) do
    local native = ChatFontNormal:GetFontObjectForAlphabet(alphabet)
    if not native then return end
    local path, size, flags = native:GetFont()
    if not path then return end
    nativeFontPaths[alphabet] = path
    members[#members + 1] = {alphabet = alphabet, file = path, height = size, flags = flags or ""}
  end
  nativeMembers = members
end

local function createChatFont(name)
  initNativeFonts()
  if nativeMembers then return CreateFontFamily(name, nativeMembers) end
  return CreateFont(name)
end

-- Applies a setter to every alphabet member of a font family, or to a plain font.
local function eachMember(fontObject, callback)
  if not nativeMembers or not fontObject.GetFontObjectForAlphabet then
    callback(fontObject)
    return
  end
  for _, alphabet in ipairs(ALPHABETS) do
    local member = fontObject:GetFontObjectForAlphabet(alphabet)
    if member then callback(member, alphabet) end
  end
end

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
  local selectedPath = LSM:Fetch(LSM.MediaType.FONT, selected, true)

  eachMember(fontObject, function (member, alphabet)
    local fallbackPath = alphabet and nativeFontPaths[alphabet] or defaultFontPath
    local fontPath = (alphabet == nil or alphabet == "roman") and selectedPath or fallbackPath
    fontPath = fontPath or fallbackPath
    if fontPath == nil then
      return
    end
    local ok, applied = pcall(
      member.SetFont,
      member,
      fontPath,
      size,
      flags
    )

    if (not ok or applied == false) and fallbackPath then
      member:SetFont(fallbackPath, size, flags)
    end
    member:SetShadowColor(0, 0, 0, shadow and 1 or 0)
    member:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
  end)
end

local function setTextColor(fontObject, color)
  eachMember(fontObject, function (member)
    member:SetTextColor(color.r, color.g, color.b, 1)
  end)
end

local function setSpacing(fontObject, spacing)
  eachMember(fontObject, function (member)
    member:SetSpacing(spacing)
  end)
end

local function setJustify(fontObject)
  fontObject:SetJustifyH("LEFT")
  fontObject:SetJustifyV("MIDDLE")
  eachMember(fontObject, function (member)
    member:SetJustifyH("LEFT")
    member:SetJustifyV("MIDDLE")
  end)
end

local function setCombatLogHighlightColor(fontObject)
  setTextColor(fontObject, Core.db.profile.tabHighlightTextColor or Constants.COLORS.apache)
end

function Fonts:OnInitialize()
  self.fonts = {}
end

function Fonts:OnEnable()
  -- GlassyMessageFont
  self.fonts.GlassyMessageFont = createChatFont("GlassyMessageFont")
  setFont(self.fonts.GlassyMessageFont, Core.db.profile.messageFontSize, "messageFont")
  setJustify(self.fonts.GlassyMessageFont)
  setSpacing(self.fonts.GlassyMessageFont, Core.db.profile.messageLeading)

  -- GlassyChatDockFont
  self.fonts.GlassyChatDockFont = createChatFont("GlassyChatDockFont")
  setFont(self.fonts.GlassyChatDockFont, Core.db.profile.tabFontSize, "tabFont")
  setJustify(self.fonts.GlassyChatDockFont)
  setSpacing(self.fonts.GlassyChatDockFont, 3)

  -- Combat Log filter buttons
  self.fonts.GlassyCombatLogNormalFont = createChatFont("GlassyCombatLogNormalFont")
  setFont(self.fonts.GlassyCombatLogNormalFont, Core.db.profile.tabFontSize, "tabFont")
  setTextColor(self.fonts.GlassyCombatLogNormalFont, Core.db.profile.tabTextColor)
  setJustify(self.fonts.GlassyCombatLogNormalFont)

  self.fonts.GlassyCombatLogHighlightFont = createChatFont("GlassyCombatLogHighlightFont")
  setFont(self.fonts.GlassyCombatLogHighlightFont, Core.db.profile.tabFontSize, "tabFont")
  setCombatLogHighlightColor(self.fonts.GlassyCombatLogHighlightFont)
  setJustify(self.fonts.GlassyCombatLogHighlightFont)

  self.fonts.GlassyCombatLogActiveFont = createChatFont("GlassyCombatLogActiveFont")
  setFont(self.fonts.GlassyCombatLogActiveFont, Core.db.profile.tabFontSize, "tabFont")
  setCombatLogHighlightColor(self.fonts.GlassyCombatLogActiveFont)
  setJustify(self.fonts.GlassyCombatLogActiveFont)

  -- GlassyEditBoxFont
  self.fonts.GlassyEditBoxFont = createChatFont("GlassyEditBoxFont")
  setFont(self.fonts.GlassyEditBoxFont, Core.db.profile.editBoxFontSize, "editBoxFont")
  setJustify(self.fonts.GlassyEditBoxFont)
  setSpacing(self.fonts.GlassyEditBoxFont, 3)

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "font" or key == "messageFontSize" then
      setFont(self.fonts.GlassyMessageFont, Core.db.profile.messageFontSize, "messageFont")
    end

    if key == "messageLeading" then
      setSpacing(self.fonts.GlassyMessageFont, Core.db.profile.messageLeading)
    end

    if key == "font" or key == "tabFontSize" then
      setFont(self.fonts.GlassyChatDockFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.GlassyCombatLogNormalFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.GlassyCombatLogHighlightFont, Core.db.profile.tabFontSize, "tabFont")
      setFont(self.fonts.GlassyCombatLogActiveFont, Core.db.profile.tabFontSize, "tabFont")
    end

    if key == "tabTextColor" then
      setTextColor(self.fonts.GlassyCombatLogNormalFont, Core.db.profile.tabTextColor)
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
