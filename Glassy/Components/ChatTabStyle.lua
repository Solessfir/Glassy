local Core, Constants = unpack(select(2, ...))

local ASSETS = "Interface\\AddOns\\Glassy\\Glassy\\Assets\\Tabs\\"

local STYLES = {
  minimal = {},
  framed = {
    shape = "tabBackground", border = "tabBorder", margin = 8, padding = 12,
    background = {normal = {0, 0, 0, 0.5}, hover = {0.08, 0.08, 0.08, 0.65}, selected = {0.05, 0.05, 0.05, 0.75}},
    outline = {normal = {0.45, 0.33, 0.20, 0.7}, hover = {0.72, 0.49, 0.30, 0.9}, selected = {accent = true, a = 1}},
  },
  solid = {
    shape = "tabBackground", margin = 8, padding = 12,
    background = {normal = {0.10, 0.10, 0.10, 0.7}, hover = {0.18, 0.18, 0.18, 0.8}, selected = {accent = true, a = 0.95}},
  },
  underline = {
    padding = 9, labelY = 2,
    bar = {hover = {1, 1, 1, 0.35, height = 1}, selected = {accent = true, a = 1, height = 3}},
  },
  pill = {
    shape = "tabPill", border = "tabPillBorder", margin = 15, padding = 16,
    background = {normal = {0, 0, 0, 0.45}, hover = {0.10, 0.10, 0.10, 0.6}, selected = {accent = true, a = 0.35}},
    outline = {normal = {1, 1, 1, 0.12}, hover = {1, 1, 1, 0.3}, selected = {accent = true, a = 1}},
  },
  glossy = {
    shape = "tabBevel", border = "tabBorder", shine = "tabShine", margin = 8, padding = 12,
    background = {normal = {0.32, 0.24, 0.18, 0.9}, hover = {0.42, 0.32, 0.24, 0.92}, selected = {0.45, 0.22, 0.12, 0.95}},
    outline = {normal = {0, 0, 0, 0.85}, hover = {0.25, 0.18, 0.12, 0.9}, selected = {accent = true, a = 1}},
    gloss = {normal = {1, 1, 1, 0.6}, hover = {1, 1, 1, 0.7}, selected = {1, 1, 1, 0.8}},
  },
  classic = {padding = 12},
}

function Core.Components.GetChatTabStyle()
  local name = Core.db.profile.tabStyle
  return STYLES[name] and name or "minimal"
end

function Core.Components.GetChatTabContentPadding()
  local style = STYLES[Core.Components.GetChatTabStyle()]
  return style.padding, style.labelY or 0
end

function Core.Components.GetChatTabAccent()
  local accent = Core:GetThemeColor("tabHighlightTextColor") or Constants.COLORS.apache
  if Core.db.profile.tabAccentClassColor and _G.UnitClass then
    local _, class = _G.UnitClass("player")
    if (not _G.canaccessvalue or _G.canaccessvalue(class)) and class then
      local color = (_G.C_ClassColor and _G.C_ClassColor.GetClassColor and _G.C_ClassColor.GetClassColor(class))
        or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class])
      if color then return {r = color.r, g = color.g, b = color.b, a = accent.a} end
    end
  end
  return accent
end

local function resolveColor(color)
  if color.accent then
    local accent = Core.Components.GetChatTabAccent()
    return accent.r, accent.g, accent.b, color.a
  end
  return unpack(color)
end

local function renderLayer(texture, file, color, margin)
  if not file or not color then
    texture:Hide()
    return
  end
  texture:SetTexture(ASSETS..file)
  if texture.SetTextureSliceMargins then
    texture:SetTextureSliceMargins(margin, margin, margin, margin)
    if texture.SetTextureSliceMode and _G.Enum and _G.Enum.UITextureSliceMode then
      texture:SetTextureSliceMode(_G.Enum.UITextureSliceMode.Stretched)
    end
  end
  texture:SetVertexColor(resolveColor(color))
  texture:Show()
end

-- Shared with the dock's moving selection so it uses exactly the tab's selected artwork.
function Core.Components.RenderChatTabStyle(host, name, state)
  local style = STYLES[name] or STYLES.minimal
  local layers = host.glassyStyleLayers
  if not layers and (state == "hidden" or not (style.shape or style.bar)) then return end
  if not layers then
    layers = {}
    for index = 1, 3 do
      local texture = host:CreateTexture(nil, "BACKGROUND", nil, index - 9)
      texture:SetPoint("TOPLEFT", 2, -1)
      texture:SetPoint("BOTTOMRIGHT", -2, 1)
      layers[index] = texture
    end
    local bar = host:CreateTexture(nil, "BACKGROUND", nil, -5)
    bar:SetPoint("BOTTOMLEFT", 2, 1)
    bar:SetPoint("BOTTOMRIGHT", -2, 1)
    layers[4] = bar
    host.glassyStyleLayers = layers
  end
  renderLayer(layers[1], style.shape, style.background and style.background[state], style.margin)
  renderLayer(layers[2], style.shine, style.gloss and style.gloss[state], style.margin)
  renderLayer(layers[3], style.border, style.outline and style.outline[state], style.margin)
  local bar = style.bar and style.bar[state]
  if bar then
    layers[4]:SetHeight(bar.height)
    layers[4]:SetColorTexture(resolveColor(bar))
    layers[4]:Show()
  else
    layers[4]:Hide()
  end
end
