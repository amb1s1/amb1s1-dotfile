-- modules/power.lua
--
-- Sleep/wake hooks. Two things macOS will not do for you:
--   1. eject external disks before sleeping (avoids the "disk not ejected
--      properly" warning and the small risk that comes with it)
--   2. react to wake, for helpers that do not survive a display sleep cleanly
--
-- hs.caffeinate.watcher is the only supported way to get these events.

local EJECT_ON_SLEEP = false  -- set true once you are happy with the behaviour

local watcher = hs.caffeinate.watcher.new(function(event)
  local w = hs.caffeinate.watcher

  if event == w.systemWillSleep then
    if EJECT_ON_SLEEP then
      -- Eject every external physical disk. diskutil is a no-op when none are
      -- attached, so this is safe to fire unconditionally.
      hs.execute(
        "/usr/sbin/diskutil list external physical " ..
        "| /usr/bin/grep -o '/dev/disk[0-9]*' " ..
        "| /usr/bin/sort -u " ..
        "| /usr/bin/xargs -n1 /usr/sbin/diskutil eject",
        true
      )
    end

  elseif event == w.screensDidWake or event == w.systemDidWake then
    -- Hook point: previously reasserted the borders overlay, which does not
    -- always survive a wake. Nothing to restore now.

  elseif event == w.screensDidLock then
    -- Hook point: pause music, mark yourself away, etc.

  end
end)

watcher:start()

return watcher
