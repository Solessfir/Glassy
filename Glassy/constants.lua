local _, Constants = unpack(select(2, ...))

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE
local WOW_PROJECT_ID = WOW_PROJECT_ID
-- luacheck: pop

-- Constants
Constants.DOCK_HEIGHT = 20
Constants.COMBAT_LOG_BAR_HEIGHT = 20
Constants.EDIT_BOX_TRANSITION_DURATION = 0.2
Constants.TEXT_RIGHT_PADDING = 15

Constants.ENV = WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and "retail" or "classic"

-- Colors
local function createColor(r, g, b)
  return {r = r / 255, g = g / 255, b = b / 255}
end

Constants.COLORS = {
  apache = createColor(223, 186, 105)
}

-- Events
Constants.EVENTS = {
  EDIT_BOX_LAYOUT_CHANGED = "Glassy/EDIT_BOX_LAYOUT_CHANGED",
  EDIT_BOX_VISIBILITY_CHANGED = "Glassy/EDIT_BOX_VISIBILITY_CHANGED",
  HYPERLINK_CLICK = "Glassy/HYPERLINK_CLICK",
  HYPERLINK_ENTER = "Glassy/HYPERLINK_ENTER",
  HYPERLINK_LEAVE = "Glassy/HYPERLINK_LEAVE",
  LOCK_MOVER = "Glassy/LOCK_MOVER",
  MOUSE_ENTER = "Glassy/MOUSE_ENTER",
  MOUSE_LEAVE = "Glassy/MOUSE_LEAVE",
  OPEN_NEWS = "Glassy/OPEN_NEWS",
  REFRESH_CONFIG = "Glassy/REFRESH_CONFIG",
  SAVE_FRAME_POSITION = "Glassy/SAVE_FRAME_POSITION",
  UNLOCK_MOVER = "Glassy/UNLOCK_MOVER",
  UPDATE_CONFIG = "Glassy/UPDATE_CONFIG",
}

Constants.ACTIONS = {
  EditBoxLayoutChanged = function ()
    return Constants.EVENTS.EDIT_BOX_LAYOUT_CHANGED
  end,
  EditBoxVisibilityChanged = function (visible)
    return Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED, visible
  end,
  HyperlinkClick = function (payload)
    return Constants.EVENTS.HYPERLINK_CLICK, payload
  end,
  HyperlinkEnter = function (payload)
    return Constants.EVENTS.HYPERLINK_ENTER, payload
  end,
  HyperlinkLeave = function (link)
    return Constants.EVENTS.HYPERLINK_LEAVE, link
  end,
  LockMover = function ()
    return Constants.EVENTS.LOCK_MOVER
  end,
  MouseEnter = function ()
    return Constants.EVENTS.MOUSE_ENTER
  end,
  MouseLeave = function ()
    return Constants.EVENTS.MOUSE_LEAVE
  end,
  OpenNews = function ()
    return Constants.EVENTS.OPEN_NEWS
  end,
  RefreshConfig = function ()
    return Constants.EVENTS.REFRESH_CONFIG
  end,
  SaveFramePosition = function (payload)
    return Constants.EVENTS.SAVE_FRAME_POSITION, payload
  end,
  UnlockMover = function ()
    return Constants.EVENTS.UNLOCK_MOVER
  end,
  UpdateConfig = function (payload)
    return Constants.EVENTS.UPDATE_CONFIG, payload
  end,
}
