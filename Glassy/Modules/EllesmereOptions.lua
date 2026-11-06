local Core, Constants = unpack(select(2, ...))
local Ellesmere = Core:GetModule("Ellesmere")

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG
local APP = "Glassy"
local PLUGIN_ID = "Glassy"

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs
-- luacheck: pop

----
-- Mirrors Glassy's AceConfig options in the EllesmereUI options panel, so both panels always offer the same settings.
-- Options are evaluated the way AceConfigDialog evaluates them: inherited handlers, getters and setters,
-- cascading hidden and disabled states, and the info table AceConfig passes to every callback.

local INHERITED = {get = true, set = true, func = true, validate = true, confirm = true, handler = true}
local DISCRETE_TYPES = {toggle = true, select = true, multiselect = true, execute = true, input = true}
local DISABLED_ALPHA = 0.35
local ROW_GAP = 4

local function getRoot()
  local registry = Core.Libs.AceConfigRegistry
  return registry:GetOptionsTable(APP, "dialog", "Glassy-1.0")
end

-- Same ordering as AceConfigDialog: by order (default 100), negative orders last, then by name.
local function sortedArgs(group, nameOf)
  local list = {}
  for key, option in pairs(group.args or {}) do
    list[#list + 1] = {key = key, option = option, name = nameOf(option, key)}
  end
  table.sort(list, function (left, right)
    local leftOrder, rightOrder = left.option.order or 100, right.option.order or 100
    if leftOrder == rightOrder then return tostring(left.name):upper() < tostring(right.name):upper() end
    if (leftOrder < 0) ~= (rightOrder < 0) then return leftOrder >= 0 end
    return leftOrder < rightOrder
  end)
  return list
end

-- A chain is the list of nodes from the root group down to one option; path holds their keys.
local function inherited(chain, field)
  for index = #chain, 1, -1 do
    local value = chain[index][field]
    if value ~= nil then return value end
  end
end

local function makeInfo(chain, path)
  local option = chain[#chain]
  local info = {}
  for index, key in ipairs(path) do info[index] = key end
  info.options, info.option, info.arg, info.type = chain[1], option, option.arg, option.type
  info.handler = inherited(chain, "handler")
  info.uiType, info.uiName, info.appName = "dialog", APP, APP
  return info
end

-- Calls a function or handler method, or returns a plain value, as AceConfig does.
local function resolve(value, info, ...)
  if type(value) == "function" then return value(info, ...) end
  if type(value) == "string" and info.handler and type(info.handler[value]) == "function" then
    return info.handler[value](info.handler, info, ...)
  end
  return value
end

local function field(chain, path, name, ...)
  local value = INHERITED[name] and inherited(chain, name) or chain[#chain][name]
  if value == nil or value == false and (name == "get" or name == "set") then return nil end
  return resolve(value, makeInfo(chain, path), ...)
end

local function isFlagged(chain, path, name)
  for depth = 1, #chain do
    local subChain, subPath = {}, {}
    for index = 1, depth do subChain[index] = chain[index] end
    for index = 1, depth - 1 do subPath[index] = path[index] end
    if chain[depth][name] ~= nil and resolve(chain[depth][name], makeInfo(subChain, subPath)) then return true end
  end
  return false
end

local function textOf(chain, path, name)
  local value = field(chain, path, name)
  return type(value) == "string" and value or ""
end

local confirmDialog = "GLASSY_ELLESMERE_CONFIRM"

-- Runs a change after the option's confirm prompt, when it has one.
local function confirmThen(chain, path, action, ...)
  local confirm = inherited(chain, "confirm")
  local text = confirm and resolve(confirm, makeInfo(chain, path), ...)
  if not text then
    action()
    return
  end
  if type(text) ~= "string" then
    text = chain[#chain].confirmText or textOf(chain, path, "name")
  end
  StaticPopupDialogs[confirmDialog] = StaticPopupDialogs[confirmDialog] or {
    text = "%s", button1 = _G.YES, button2 = _G.NO, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function (_, data) data() end,
  }
  StaticPopup_Show(confirmDialog, text, nil, action)
end

-- Rebuilds are deferred so a setter never tears down the widget that is calling it.
function Ellesmere:ScheduleOptionsRefresh(force)
  self.optionsRefreshForce = self.optionsRefreshForce or force
  if self.optionsRefreshPending then return end
  self.optionsRefreshPending = true
  C_Timer.After(0, function ()
    self.optionsRefreshPending = false
    local forced = self.optionsRefreshForce
    self.optionsRefreshForce = false
    local EllesmereUI = _G.EllesmereUI
    if not (EllesmereUI and EllesmereUI.GetPluginModuleKey and EllesmereUI.GetActiveModule) then return end
    local active = EllesmereUI:GetActiveModule()
    for _, key in ipairs(self.optionModuleKeys or {}) do
      local fullKey = EllesmereUI.GetPluginModuleKey(PLUGIN_ID, key)
      if fullKey and fullKey == active then
        EllesmereUI:RefreshPage(forced)
      elseif fullKey and forced and EllesmereUI.InvalidateModulePageCache then
        EllesmereUI:InvalidateModulePageCache(fullKey)
      end
    end
  end)
end

local function applyChange(self, chain, path, method, ...)
  local value = INHERITED[method] and inherited(chain, method) or nil
  if value == nil or value == false then return end
  resolve(value, makeInfo(chain, path), ...)
  local discrete = DISCRETE_TYPES[chain[#chain].type]
  if discrete then
    -- Keeps Glassy's own panel in step; its change callback rebuilds this page for new hidden and disabled states.
    local registry = Core.Libs.AceConfigRegistry
    registry:NotifyChange(APP)
  else
    -- Sliders and color pickers call this continuously, so they only re-read values in place.
    self:ScheduleOptionsRefresh(false)
  end
end

-- The search pre-build pass hands out stand-in frames that cannot parent real ones.
local function dim(ctx, frame, disabled)
  if not disabled or not frame or ctx.prebuild then return end
  frame:SetAlpha(DISABLED_ALPHA)
  local blocker = CreateFrame("Frame", nil, frame)
  blocker:SetAllPoints()
  blocker:SetFrameLevel(frame:GetFrameLevel() + 20)
  blocker:EnableMouse(true)
end

local function makeLabel(parent, size)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local path, _, flags = label:GetFont()
  if path then label:SetFont(path, size, flags) end
  if Ellesmere.skin and Ellesmere.skin.Font then pcall(Ellesmere.skin.Font, label) end
  label:SetJustifyH("LEFT")
  label:SetWordWrap(true)
  return label
end

local DESCRIPTION_SIZES = {small = 12, medium = 14, large = 16}

local function descriptionRow(ctx, text, fontSize)
  if text == "" or text == " " then return ctx.y - (text == " " and 12 or 0) end
  if ctx.prebuild then return ctx.y - 30 end
  local width = ctx.parent:GetWidth() - ctx.pad * 2
  local frame = CreateFrame("Frame", nil, ctx.parent)
  frame:SetPoint("TOPLEFT", ctx.parent, "TOPLEFT", ctx.pad, ctx.y)
  frame:SetWidth(width)
  local label = makeLabel(frame, DESCRIPTION_SIZES[fontSize] or 13)
  label:SetPoint("TOPLEFT", 20, -8)
  label:SetWidth(width - 40)
  label:SetText(text)
  local height = label:GetStringHeight() + 16
  frame:SetHeight(height)
  return ctx.y - height - ROW_GAP, frame
end

-- Clicking another button never takes focus from a text box, so like AceConfig's own input an Accept button
-- commits the text; Enter and leaving the box commit it too.
local function inputRow(ctx, text, multiline, getText, commit)
  local height = multiline and (math.max(3, tonumber(multiline) or 4) * 14 + 82) or 50
  if ctx.prebuild then return ctx.y - height end
  local width = ctx.parent:GetWidth() - ctx.pad * 2
  local frame = CreateFrame("Frame", nil, ctx.parent)
  frame:SetPoint("TOPLEFT", ctx.parent, "TOPLEFT", ctx.pad, ctx.y)
  frame:SetSize(width, height)
  local label = makeLabel(frame, 14)
  label:SetText(text)

  local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  accept:SetSize(90, 22)
  accept:SetText(_G.ACCEPT or "Accept")
  if Ellesmere.skin then pcall(Ellesmere.skin.Button, accept) end

  local editBox
  if multiline then
    label:SetPoint("TOPLEFT", 20, -8)
    accept:SetPoint("BOTTOMRIGHT", -20, 8)
    local container = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 20, -30)
    container:SetPoint("BOTTOMRIGHT", -20, 38)
    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(width - 80)
    scroll:SetScrollChild(editBox)
    -- An empty box is one line tall, so the whole frame focuses it.
    container:EnableMouse(true)
    container:SetScript("OnMouseDown", function () editBox:SetFocus() end)
    if Ellesmere.skin then
      pcall(Ellesmere.skin.Panel, container, {inset = true})
      pcall(Ellesmere.skin.ScrollBar, scroll.ScrollBar)
    end
  else
    label:SetPoint("LEFT", 20, 0)
    accept:SetPoint("RIGHT", -20, 0)
    editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(240, 24)
    editBox:SetPoint("RIGHT", accept, "LEFT", -12, 0)
    if Ellesmere.skin then pcall(Ellesmere.skin.EditBox, editBox) end
  end
  editBox:SetAutoFocus(false)
  editBox:SetText(getText() or "")
  -- Accept also clears focus, so remember the text it just submitted instead of reporting a rejection twice.
  local submitted
  local function submit()
    local value = editBox:GetText()
    if value == (getText() or "") or value == submitted then return end
    submitted = value
    commit(value)
  end
  editBox:HookScript("OnTextChanged", function (_, userInput)
    if userInput then submitted = nil end
  end)
  if not multiline then
    editBox:SetScript("OnEnterPressed", function (box) submit(); box:ClearFocus() end)
  end
  editBox:SetScript("OnEscapePressed", function (box)
    box:SetText(getText() or "")
    box:ClearFocus()
  end)
  editBox:HookScript("OnEditFocusLost", submit)
  accept:SetScript("OnClick", function ()
    submit()
    editBox:ClearFocus()
  end)
  return ctx.y - height - ROW_GAP, frame
end

local function valuesOf(chain, path)
  local option = chain[#chain]
  local values = resolve(option.values, makeInfo(chain, path)) or {}
  local labels = {}
  for key, label in pairs(values) do
    -- Font pickers list font names mapped to file paths; the names are what users choose.
    labels[key] = option.dialogControl == "LSM30_Font" and key or label
  end
  local sorting = option.sorting and resolve(option.sorting, makeInfo(chain, path))
  if type(sorting) == "table" then return labels, sorting end
  local order = {}
  for key in pairs(labels) do order[#order + 1] = key end
  table.sort(order, function (left, right) return tostring(labels[left]) < tostring(labels[right]) end)
  return labels, order
end

-- Setters for discrete choices run behind the option's confirm prompt, like AceConfigDialog.
local function confirmedSetter(self, chain, path)
  return function (value)
    confirmThen(chain, path, function () applyChange(self, chain, path, "set", value) end, value)
  end
end

local renderGroup

local function renderOption(self, ctx, chain, path)
  local option = chain[#chain]
  local W = ctx.widgets
  local name = textOf(chain, path, "name")
  local tooltip = textOf(chain, path, "desc")
  tooltip = tooltip ~= "" and tooltip or nil
  local disabled = isFlagged(chain, path, "disabled")
  local kind = option.type
  local frame, height

  if kind == "group" then
    -- Unnamed rows of descriptions (a command beside what it does) read as one line.
    if name == "" and option.inline then
      local texts, onlyDescriptions = {}, true
      for _, entry in ipairs(sortedArgs(option, function (child, key) return child.name or key end)) do
        if entry.option.type ~= "description" then
          onlyDescriptions = false
          break
        end
        local childChain, childPath = {unpack(chain)}, {unpack(path)}
        childChain[#childChain + 1] = entry.option
        childPath[#childPath + 1] = entry.key
        texts[#texts + 1] = textOf(childChain, childPath, "name")
      end
      if onlyDescriptions and #texts > 1 then
        ctx.y = descriptionRow(ctx, table.concat(texts, "  "), "medium")
        return
      end
    end
    if name ~= "" then
      local _, headerHeight = W:SectionHeader(ctx.parent, name, ctx.y)
      ctx.y = ctx.y - headerHeight
    end
    renderGroup(self, ctx, chain, path)
    return
  elseif kind == "header" then
    frame, height = W:SectionHeader(ctx.parent, name, ctx.y)
  elseif kind == "description" then
    local y
    y, frame = descriptionRow(ctx, name, option.fontSize)
    ctx.y = y
    dim(ctx, frame, disabled)
    return
  elseif kind == "toggle" then
    frame, height = W:Toggle(ctx.parent, name, ctx.y,
      function () return field(chain, path, "get") and true or false end,
      confirmedSetter(self, chain, path),
      tooltip)
  elseif kind == "range" then
    local minimum = option.softMin or option.min or 0
    local maximum = option.softMax or option.max or 100
    frame, height = W:Slider(ctx.parent, name, ctx.y, minimum, maximum, option.step or option.bigStep or 1,
      function () return field(chain, path, "get") end,
      function (value) applyChange(self, chain, path, "set", value) end,
      tooltip)
  elseif kind == "select" then
    local labels, order = valuesOf(chain, path)
    frame, height = W:Dropdown(ctx.parent, name, ctx.y, labels,
      function () return field(chain, path, "get") end,
      confirmedSetter(self, chain, path),
      order, tooltip)
  elseif kind == "multiselect" then
    frame, height = W:SectionHeader(ctx.parent, name, ctx.y, tooltip)
    ctx.y = ctx.y - height
    dim(ctx, frame, disabled)
    local labels, order = valuesOf(chain, path)
    for _, key in ipairs(order) do
      local row, rowHeight = W:Checkbox(ctx.parent, tostring(labels[key]), ctx.y,
        function () return field(chain, path, "get", key) and true or false end,
        function (value) applyChange(self, chain, path, "set", key, value) end,
        tooltip)
      ctx.y = ctx.y - rowHeight
      dim(ctx, row, disabled)
    end
    return
  elseif kind == "color" then
    frame, height = W:ColorPicker(ctx.parent, name, ctx.y,
      function () return field(chain, path, "get") end,
      function (r, g, b, a) applyChange(self, chain, path, "set", r, g, b, a) end,
      option.hasAlpha)
  elseif kind == "execute" then
    frame, height = W:Button(ctx.parent, name, ctx.y, function ()
      confirmThen(chain, path, function () applyChange(self, chain, path, "func") end)
    end)
  elseif kind == "input" then
    local y
    y, frame = inputRow(ctx, name, option.multiline,
      function () local value = field(chain, path, "get"); return type(value) == "string" and value or "" end,
      function (value)
        local valid = field(chain, path, "validate", value)
        if type(valid) == "string" then
          Core:GetModule("Config"):Print(valid)
          return
        end
        if valid ~= false then applyChange(self, chain, path, "set", value) end
      end)
    ctx.y = y
    dim(ctx, frame, disabled)
    return
  else
    return
  end

  ctx.y = ctx.y - (height or 0)
  dim(ctx, frame, disabled)
end

renderGroup = function (self, ctx, chain, path)
  local group = chain[#chain]
  local function nameOf(option, key)
    local value = option.name
    return type(value) == "string" and value or key
  end
  for _, entry in ipairs(sortedArgs(group, nameOf)) do
    local option = entry.option
    if not option.dialogHidden then
      local childChain, childPath = {}, {}
      for index, node in ipairs(chain) do childChain[index] = node end
      for index, key in ipairs(path) do childPath[index] = key end
      childChain[#childChain + 1] = option
      childPath[#childPath + 1] = entry.key
      if not isFlagged(childChain, childPath, "hidden") then
        renderOption(self, ctx, childChain, childPath)
      end
    end
  end
end

-- Options are usually keyed by the profile setting they change; these save under another setting.
local SETTING_ALIASES = {
  editBoxAnchorPosition = "editBoxAnchor",
  editBoxAnchorYOfs = "editBoxAnchor",
  frameAnchor = "positionAnchor",
  frameXOfs = "positionAnchor",
  frameYOfs = "positionAnchor",
  combatLogVisible = "combatLogHidden",
  fadeEasing = "chatFadeEasing",
  fadeInDuration = "chatFadeInDuration",
  fadeOutDuration = "chatFadeOutDuration",
  slideInDuration = "chatSlideInDuration",
  slideInEasing = "chatSlideInEasing",
}

local function collectSettings(group, settings)
  for key, option in pairs(group.args or {}) do
    if option.type == "group" then
      collectSettings(option, settings)
    else
      local setting = SETTING_ALIASES[key] or key
      if Core.defaults.profile[setting] ~= nil then settings[setting] = true end
    end
  end
  return settings
end

local function copyValue(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[key] = copyValue(entry) end
  return copy
end

-- EllesmereUI confirms a reset and reloads the UI afterwards, so restoring the saved defaults is enough.
local function resetSettings(settings)
  for setting in pairs(settings) do
    Core.db.profile[setting] = copyValue(Core.defaults.profile[setting])
  end
end

-- Every top-level Glassy settings group becomes one EllesmereUI module with a single scrolling page.
function Ellesmere:BuildOptionModules(root)
  local modules = {}
  self.optionModuleKeys = {}
  local function nameOf(option, key) return type(option.name) == "string" and option.name or key end
  for _, entry in ipairs(sortedArgs(root, nameOf)) do
    local group = entry.option
    if group.type == "group" and not group.dialogHidden then
      local title = nameOf(group, entry.key)
      -- EllesmereUI prefixes titles that match its own sections, such as Profiles.
      if entry.key == "profile" then title = "Glassy "..title:lower() end
      local key = entry.key
      self.optionModuleKeys[#self.optionModuleKeys + 1] = key
      -- Only sections that hold settings offer EllesmereUI's Reset button.
      local settings = collectSettings(group, {})
      local onReset = next(settings) and function () resetSettings(settings) end or nil
      modules[#modules + 1] = {
        key = key,
        title = title,
        description = type(group.desc) == "string" and group.desc or nil,
        pages = {title},
        buildPage = function (_, parent, yOffset)
          local EllesmereUI = _G.EllesmereUI
          local currentRoot = getRoot()
          local currentGroup = currentRoot.args[key]
          if not currentGroup then return 0 end
          local ctx = {
            parent = parent, y = yOffset, widgets = EllesmereUI.Widgets,
            pad = EllesmereUI.CONTENT_PAD or 45,
            prebuild = EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild() or false,
          }
          renderGroup(self, ctx, {currentRoot, currentGroup}, {key})
          return math.abs(ctx.y - yOffset) + 20
        end,
        -- Status lines and dynamic lists are read when a page is built, so cached pages rebuild on return.
        onPageCacheRestore = function () self:ScheduleOptionsRefresh(true) end,
        onReset = onReset,
      }
    end
  end
  return modules
end

function Ellesmere:RegisterOptions()
  local EllesmereUI = _G.EllesmereUI
  if self.optionsRegistered or not (EllesmereUI and EllesmereUI.RegisterPlugin) then return end
  local root = getRoot()
  if not root then return end
  self.optionsRegistered = EllesmereUI.RegisterPlugin(PLUGIN_ID, {
    label = "Glassy",
    modules = self:BuildOptionModules(root),
  })
  if not self.optionsRegistered then return end

  local registry = Core.Libs.AceConfigRegistry
  registry.RegisterCallback(self, "ConfigTableChange", function (_, appName)
    if appName == APP then self:ScheduleOptionsRefresh(true) end
  end)
  Core:Subscribe(UPDATE_CONFIG, function () self:ScheduleOptionsRefresh(false) end)
  for _, event in ipairs({"OnProfileChanged", "OnProfileCopied", "OnProfileReset"}) do
    Core.db.RegisterCallback(self, event, function () self:ScheduleOptionsRefresh(true) end)
  end
end

function Ellesmere:OnEnable()
  self:RegisterOptions()
end
