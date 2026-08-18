-- ~/.hammerspoon/init.lua
--
-- SCOPE: event glue ONLY.
--
-- Window management is plain macOS. Launchers live in Leader Key / Raycast.
-- Key remapping lives in Karabiner (~/.config/karabiner.edn).
--
-- Hammerspoon is here for the one thing nothing else exposes: reacting to
-- macOS system events. Keep this file small. If a module grows past ~60 lines,
-- ask whether a purpose-built tool should own it instead.

hs.console.clearConsole()
hs.window.animationDuration = 0

-- Shared helpers ------------------------------------------------------------

local M = {}

-- Non-blocking notification. Uses hs.alert (on-screen, transient) rather than
-- hs.notify so it never lands in Notification Center history.
function M.toast(msg, seconds)
  hs.alert.closeAll()
  hs.alert.show(msg, seconds or 2)
end

_G.hsutil = M

-- Modules -------------------------------------------------------------------
-- Each returns nothing; they install their own watchers and hold them in
-- module-level locals so the GC does not collect them.

require("modules.wifi")        -- SSID changes -> announce trust zone
require("modules.camera")      -- camera in use -> on-screen "on air" alert
require("modules.power")       -- sleep/wake -> tidy up
require("modules.usbconsole")  -- USB serial adapter -> offer a console session
require("modules.urldispatch") -- route work URLs to the work browser profile

-- Config reload -------------------------------------------------------------

local configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
  for _, f in ipairs(files) do
    if f:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end):start()

-- Keep a reference so the watcher is not garbage collected.
_G.__configWatcher = configWatcher

M.toast("Hammerspoon loaded")
