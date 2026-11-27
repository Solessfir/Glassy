local Core, Constants, Utils = unpack(select(2, ...))
local Rules = Core:GetModule("ChatRules")

local MAX_SOURCE, MAX_RULES, MAX_FIELD, MAX_MESSAGE, MAX_PATTERN_TEXT = 16384, 100, 256, 32768, 512
local cache = {}

local function plainString(value)
  return (not _G.canaccessvalue or _G.canaccessvalue(value)) and type(value) == "string"
end

local function trim(text)
  return text:match("^%s*(.-)%s*$")
end

local function normalize(text)
  return Utils.lower(text):gsub("%s+", " ")
end

---@param pattern string
local function validPattern(pattern)
  local cursor, repetitions, captures, totalCaptures = 1, 0, 0, 0
  local function classEnd(start)
    local i = start + 1
    if pattern:sub(i, i) == "^" then i = i + 1 end
    repeat
      if i > #pattern then return end
      if pattern:sub(i, i) == "%" then i = i + 1 end
      i = i + 1
    until pattern:sub(i, i) == "]"
    return i + 1
  end
  while cursor <= #pattern do
    local char = pattern:sub(cursor, cursor)
    if char == "%" then
      local escaped = pattern:sub(cursor + 1, cursor + 1)
      if escaped == "" or escaped == "b" or escaped:match("%d") then return false end
      if escaped == "f" then
        if pattern:sub(cursor + 2, cursor + 2) ~= "[" then return false end
        cursor = classEnd(cursor + 2)
        if not cursor then return false end
      else cursor = cursor + 2 end
    elseif char == "[" then
      cursor = classEnd(cursor)
      if not cursor then return false end
    elseif char == "(" then
      totalCaptures, captures, cursor = totalCaptures + 1, captures + 1, cursor + 1
      if totalCaptures > 32 then return false end
    elseif char == ")" then
      captures, cursor = captures - 1, cursor + 1
      if captures < 0 then return false end
    else
      if char:find("[*+?%-]") then repetitions = repetitions + 1 end
      if repetitions > 1 then return false end
      cursor = cursor + 1
    end
  end
  return captures == 0 and pcall(string.find, "", pattern)
end

local PATTERN_ERROR = "Invalid or unsupported Lua pattern. Use at most one repetition (*, +, -, or ?), without balanced matches or backreferences."

local function parse(source, kind, patterns)
  if not plainString(source) or #source > MAX_SOURCE then return {}, "Use at most 16384 bytes." end
  local entries, lineNumber = {}, 0
  for sourceLine in (source.."\n"):gmatch("([^\n]*)\n") do
    lineNumber = lineNumber + 1
    local line = trim(sourceLine)
    if line ~= "" then
      local first, second, third
      if kind == "alts" then first, second = line:match("^(.-)%s*=%s*(.-)$")
      elseif kind == "substitutions" then first, second = line:match("^(.-)%s*=>%s*(.-)$")
      else first, second, third = line:match("^(%a+)|(%a+)|(.*)$") end
      local problem
      if kind == "filters" then
        if (first ~= "hide" and first ~= "keep") or (second ~= "plain" and second ~= "pattern") then
          problem = "Use hide|plain|text, keep|plain|text, hide|pattern|pattern, or keep|pattern|pattern."
        elseif third == "" or #third > MAX_FIELD or third:find("%c") then
          problem = "Use a nonempty match of at most 256 bytes without control characters."
        elseif second == "pattern" and not validPattern(third) then problem = PATTERN_ERROR end
      elseif not first or trim(first) == "" or #first > MAX_FIELD or #second > MAX_FIELD then
        problem = kind == "alts" and "Use Alt = Main, with names up to 256 bytes." or "Use text => replacement, with fields up to 256 bytes."
      elseif first:find("[%c|]") or second:find("[%c|]") then
        problem = "Use plain text without pipes or control characters."
      elseif kind == "alts" and (second == "" or first:find("[%[%]]") or second:find("[%[%]]")) then
        problem = "Use nonempty names without brackets."
      elseif kind == "substitutions" and patterns and not validPattern(first) then problem = PATTERN_ERROR end
      if #entries >= MAX_RULES then problem = "Use at most 100 rules." end
      if problem then return entries, "Line "..lineNumber..": "..problem end
      if kind == "alts" then entries[#entries + 1] = {Utils.lower(trim(first)), trim(second)}
      elseif kind == "filters" then entries[#entries + 1] = {first, second, third}
      else entries[#entries + 1] = {first, second} end
    end
  end
  return entries
end

local function entries(kind, source, patterns)
  local previous = cache[kind]
  if not previous or previous.source ~= source or previous.patterns ~= patterns then
    local values, problem = parse(source or "", kind, patterns)
    -- A malformed imported configuration must not partially apply a rule list.
    previous = {source = source, patterns = patterns, values = not problem and values or {}}
    cache[kind] = previous
  end
  return previous.values
end

-- Keep complete links and escape sequences opaque while changing only ordinary text.
---@param text string
local function mapText(text, transform, visible, depth)
  local parts, cursor = {}, 1
  while cursor <= #text do
    local pipe = text:find("|", cursor, true) or (#text + 1)
    parts[#parts + 1] = transform(text:sub(cursor, pipe - 1))
    if pipe > #text then break end
    local code = text:sub(pipe, pipe + 1)
    local finish, replacement
    if code == "|H" then
      local _, linkEnd, shown = text:find("^|H[^|]*|h(.-)|h", pipe)
      finish = linkEnd
      if visible and linkEnd and depth < 2 then replacement = mapText(shown, transform, true, depth + 1) end
    elseif code == "|T" or code == "|A" or code == "|K" then
      local close = ({["|T"] = "|t", ["|A"] = "|a", ["|K"] = "|k"})[code]
      local _, sequenceEnd = text:find(close, pipe + 2, true)
      finish = sequenceEnd
      if visible then replacement = code == "|K" and "" or " " end
    elseif code == "|c" and text:sub(pipe + 2, pipe + 9):match("^%x%x%x%x%x%x%x%x$") then
      finish = pipe + 9
      if visible then replacement = "" end
    elseif code == "|c" then
      -- Retail named colors such as |cnIQ4: end at the first colon.
      finish = text:find(":", pipe + 2, true)
      if visible then replacement = "" end
    elseif code == "|r" or code == "|W" or code == "|w" then
      finish = pipe + 1
      if visible then replacement = "" end
    elseif code == "||" then
      finish = pipe + 1
      if visible then replacement = "|" end
    elseif code == "|n" then
      finish = pipe + 1
      if visible then replacement = "\n" end
    elseif code == "|4" then finish = text:find(";", pipe + 2, true) end
    -- An incomplete or unknown code may contain opaque data, so leave its tail alone.
    if not finish then
      parts[#parts + 1] = visible and "" or text:sub(pipe)
      break
    end
    parts[#parts + 1] = replacement or text:sub(pipe, finish)
    cursor = finish + 1
  end
  return table.concat(parts)
end

function Rules:AppendMainName(data, shown)
  local profile = Core.db.profile
  if not profile.chatAltNamesEnabled or Core:IsPratModuleEnabled("AltNames")
    or not plainString(data) or not plainString(shown) or shown:find("|K", 1, true) then return shown end
  local name = data:match("^player:([^:]+)")
  if not name or name:find("|", 1, true) then return shown end
  name = Utils.lower(name)
  local short = name:match("^([^%-]+)")
  -- Same-realm player links omit the realm.
  local realm = short == name and _G.GetNormalizedRealmName and _G.GetNormalizedRealmName()
  local qualified = plainString(realm) and realm ~= "" and name.."-"..Utils.lower(realm) or name
  local main
  for _, entry in ipairs(entries("alts", profile.chatAltNames)) do
    if entry[1] == name or entry[1] == qualified then main = entry[2]; break end
    if entry[1] == short then main = entry[2] end
  end
  return main and (shown.." ("..main..")") or shown
end

function Rules:Substitute(text)
  local profile = Core.db.profile
  if not profile.chatSubstitutionsEnabled or Core:IsPratModuleEnabled("Substitutions")
    or not plainString(text) or #text > MAX_MESSAGE then return text end
  local values = entries("substitutions", profile.chatSubstitutions, profile.chatSubstitutionPatterns)
  if #values == 0 then return text end
  local ok, result = pcall(mapText, text, function (segment)
    for _, entry in ipairs(values) do
      if not profile.chatSubstitutionPatterns or #segment <= MAX_PATTERN_TEXT then
        local pattern = profile.chatSubstitutionPatterns and entry[1] or entry[1]:gsub("(%W)", "%%%1")
        segment = segment:gsub(pattern, function () return entry[2] end, 100)
      end
      if #segment > MAX_MESSAGE then error("Substitution output too long") end
    end
    return segment
  end, false, 0)
  return ok and #result <= MAX_MESSAGE and result or text
end

function Rules:IsMessageFiltered(text)
  local profile = Core.db.profile
  if not profile.chatFilterRulesEnabled or Core:IsPratModuleEnabled("CustomFilters")
    or not plainString(text) or #text > MAX_MESSAGE then return false end
  local visible = mapText(text, function (segment) return segment end, true, 0)
  local normalized
  for _, entry in ipairs(entries("filters", profile.chatFilterRules)) do
    local found
    if entry[2] == "plain" then
      normalized = normalized or normalize(visible)
      found = normalized:find(normalize(entry[3]), 1, true)
    elseif #visible <= MAX_PATTERN_TEXT then
      local ok, match = pcall(string.find, visible, entry[3])
      found = ok and match
    end
    if found then return entry[1] == "hide" end
  end
  return false
end

function Rules:BuildOptions()
  local function option(key, name, desc, order, pratModule, dependency, kind)
    return {
      type = kind and "input" or "toggle", name = name, desc = desc, order = order,
      width = "full", multiline = kind and 8 or nil,
      disabled = function () return Core:IsPratModuleEnabled(pratModule) or (dependency and not Core.db.profile[dependency]) end,
      get = function () return Core.db.profile[key] end,
      validate = (kind or key == "chatSubstitutionPatterns") and function (_, value)
        local _, problem
        if kind then _, problem = parse(value, kind, Core.db.profile.chatSubstitutionPatterns)
        elseif value then _, problem = parse(Core.db.profile.chatSubstitutions or "", "substitutions", true) end
        return problem or true
      end or nil,
      set = function (_, value)
        Core.db.profile[key] = value
        Core:Dispatch(Constants.ACTIONS.UpdateConfig(key:find("chatFilter", 1, true) and "messageBlacklist" or "messageFormatting"))
      end,
    }
  end
  return {
    name = "Chat rules", type = "group", order = 8,
    args = {
      description = {type = "description", order = 0, name = "These features apply to Glassy's chat display. Active Prat AltNames, Substitutions, and CustomFilters modules take precedence for their matching feature."},
      chatAltNamesEnabled = option("chatAltNamesEnabled", "Show main names", "Append a main name to mapped player links.", 1, "AltNames"),
      chatAltNames = option("chatAltNames", "Alt to main mappings", "One Alt = Main mapping per line. Names ignore case. Use Name-Realm for a specific realm; an unqualified alt matches that name on any realm. Exact realm mappings take precedence.", 2, "AltNames", "chatAltNamesEnabled", "alts"),
      chatSubstitutionsEnabled = option("chatSubstitutionsEnabled", "Substitute text", "Replace ordinary displayed text while preserving links, textures, and protected names. Original messages remain available for copying and filtering.", 3, "Substitutions"),
      chatSubstitutionPatterns = option("chatSubstitutionPatterns", "Use Lua patterns for substitutions", "Interpret searches as case-sensitive Lua patterns with at most one repetition (*, +, -, or ?), without balanced matches or backreferences. Patterns skip text spans longer than 512 bytes. Replacements are always literal text.", 4, "Substitutions", "chatSubstitutionsEnabled"),
      chatSubstitutions = option("chatSubstitutions", "Substitutions", "One text => replacement per line, applied in order. Matching is case-sensitive. Empty replacements remove matches. Pipes and control characters are not accepted. At most 100 replacements per rule and text span.", 5, "Substitutions", "chatSubstitutionsEnabled", "substitutions"),
      chatFilterRulesEnabled = option("chatFilterRulesEnabled", "Enable filter rules", "Filter Glassy's displayed messages using the original visible text, including link labels. Blocked phrases continue to apply.", 6, "CustomFilters"),
      chatFilterRules = option("chatFilterRules", "Filter rules", "One hide|plain|text, keep|plain|text, hide|pattern|pattern, or keep|pattern|pattern rule per line. The first match wins. Plain matches ignore case and repeated whitespace. Patterns are case-sensitive, allow at most one repetition, forbid balanced matches and backreferences, and skip messages longer than 512 visible bytes. Keep rules cannot override blocked phrases. Example: hide|plain|buy gold", 7, "CustomFilters", "chatFilterRulesEnabled", "filters"),
    },
  }
end
