local Core, Constants = unpack(select(2, ...))
local ChatDockMixin = Core.Components.ChatDockMixin

-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK
-- luacheck: pop

---@class GlassyTabSelectionPiece: Frame
---@field x number
---@field width number
---@field height number
---@return GlassyTabSelectionPiece
local function newPiece(dock)
  -- Keeping the art in the scroll child clips it with the tabs during overflow scrolling.
  ---@type GlassyTabSelectionPiece
  local piece = CreateFrame("Frame", nil, dock.scrollFrame.child)
  piece:SetFrameLevel(dock.scrollFrame.child:GetFrameLevel())
  piece:Hide()
  return piece
end

local function place(piece, x, width, height, scale, heightScale)
  scale = scale or 1
  piece.x, piece.width, piece.height = x, width, height
  piece:ClearAllPoints()
  piece:SetPoint("CENTER", piece:GetParent(), "LEFT", x + width / 2, 0)
  piece:SetSize(math.max(1, width * scale), math.max(1, height * (heightScale or scale)))
end

local function render(piece, style)
  Core.Components.RenderChatTabStyle(piece, style, "selected")
  if style == "minimal" then
    if not piece.line then
      piece.line = piece:CreateTexture(nil, "BACKGROUND")
      piece.line:SetColorTexture(1, 1, 1)
      piece.line:SetPoint("TOPLEFT", 2, 0)
      piece.line:SetPoint("TOPRIGHT", -2, 0)
      piece.line:SetHeight(1)
    end
    local getAccent = Core.Components.GetChatTabAccent
    local color = getAccent and getAccent() or Core:GetThemeColor("tabHighlightTextColor") or Constants.COLORS.apache
    piece.line:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    piece.line:Show()
  elseif piece.line then
    piece.line:Hide()
  end
end

function ChatDockMixin:ResetTabSelection()
  local selection = self.tabSelection
  if not selection then return end
  if selection.tab then selection.tab.glassySelectionAnimated = nil end
  selection.piece:SetScript("OnUpdate", nil)
  selection.piece:Hide()
  selection.ghost:Hide()
  selection.tab = nil
  selection.elapsed = nil
end

function ChatDockMixin:StepTabSelection(elapsed)
  local selection = self.tabSelection
  local piece = selection.piece
  selection.elapsed = selection.elapsed + elapsed
  local grow = selection.animation == "grow"
  local progress = math.min(1, selection.elapsed / (grow and 0.28 or 0.3))
  local ease
  if grow then
    local back = progress - 1
    ease = 1 + 2.4 * back * back * back + 1.4 * back * back
    local opacity = math.min(1, progress / 0.45)
    piece:SetAlpha(opacity * opacity * (3 - 2 * opacity))
    local ghost = selection.ghost
    local line = selection.style == "minimal" or selection.style == "underline"
    place(ghost, ghost.x, ghost.width, ghost.height, 1 - 0.7 * progress * progress, line and 1 or nil)
    ghost:SetAlpha(1 - progress)
  else
    ease = progress < 0.5 and 4 * progress ^ 3 or 1 - (-2 * progress + 2) ^ 3 / 2
  end
  place(piece,
    selection.fromX + (selection.x - selection.fromX) * ease,
    selection.fromWidth + (selection.width - selection.fromWidth) * ease,
    selection.fromHeight + (selection.height - selection.fromHeight) * ease)
  if progress == 1 then
    selection.elapsed = nil
    piece:SetScript("OnUpdate", nil)
    piece:SetAlpha(1)
    selection.ghost:Hide()
  end
end

function ChatDockMixin:UpdateTabSelection()
  local animation = Core.db.profile.tabSelectionAnimation
  local style = Core.Components.GetChatTabStyle and Core.Components.GetChatTabStyle() or "minimal"
  local selected = GENERAL_CHAT_DOCK.selected
  local tab = selected and _G[selected:GetName().."Tab"]
  if (animation ~= "slide" and animation ~= "grow") or style == "classic" or self.tabDrag
    or not tab or not selected.isDocked or not tab:IsShown() or tab.glassyDockOffset == nil
    or not Core.Components.RenderChatTabStyle then
    self:ResetTabSelection()
    return
  end

  local x, width, height = tab.glassyDockOffset, tab:GetWidth(), Constants.DOCK_HEIGHT
  if (_G.canaccessvalue and (not _G.canaccessvalue(x) or not _G.canaccessvalue(width)))
    or type(x) ~= "number" or type(width) ~= "number" or width <= 0 then
    self:ResetTabSelection()
    return
  end

  local selection = self.tabSelection
  if not selection then
    selection = {piece = newPiece(self), ghost = newPiece(self)}
    self.tabSelection = selection
  end
  if selection.style ~= style or selection.animation ~= animation then
    self:ResetTabSelection()
  end
  selection.style, selection.animation = style, animation
  local piece, ghost = selection.piece, selection.ghost
  render(piece, style)
  render(ghost, style)

  if tab ~= selection.tab then
    if selection.tab then
      selection.tab.glassySelectionAnimated = nil
      selection.elapsed = 0
      if animation == "grow" then
        place(ghost, piece.x, piece.width, piece.height)
        ghost:SetAlpha(piece:GetAlpha())
        ghost:Show()
        selection.fromX = x + width * 0.35
        selection.fromWidth = width * 0.3
        selection.fromHeight = (style == "minimal" or style == "underline") and height or height * 0.3
      else
        ghost:Hide()
        selection.fromX, selection.fromWidth, selection.fromHeight = piece.x, piece.width, piece.height
      end
      piece:SetScript("OnUpdate", function (_, delta) self:StepTabSelection(delta) end)
    end
    selection.tab = tab
  end
  selection.x, selection.width, selection.height = x, width, height
  tab.glassySelectionAnimated = true
  if selection.elapsed then
    self:StepTabSelection(0)
  else
    place(piece, x, width, height)
    piece:SetAlpha(1)
  end
  piece:Show()
end
