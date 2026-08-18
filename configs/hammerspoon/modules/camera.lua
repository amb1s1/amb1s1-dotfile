-- modules/camera.lua
--
-- Alert whenever any camera starts or stops being used, so "am I live?" is
-- answerable without hunting for the meeting window.
--
-- This previously recoloured the JankyBorders focus ring; borders was removed
-- along with AeroSpace, so the signal is now an on-screen toast.
--
-- This is the canonical example of something only Hammerspoon can do:
-- hs.camera exposes per-device in-use state, which no config-file tool offers.

local function anyCameraInUse()
  for _, cam in ipairs(hs.camera.allCameras()) do
    if cam:isInUse() then return true end
  end
  return false
end

-- Only announce transitions: refresh() is called on every property change, and
-- a toast on every no-op event would be noise.
local wasInUse = nil

local function refresh()
  local inUse = anyCameraInUse()
  if inUse ~= wasInUse then
    if wasInUse ~= nil then
      hsutil.toast(inUse and "🔴 camera on" or "camera off", 1)
    end
    wasInUse = inUse
  end
end

-- Attach a property watcher to every camera currently present.
local function watch(cam)
  cam:setPropertyWatcherCallback(function() refresh() end)
  cam:startPropertyWatcher()
end

for _, cam in ipairs(hs.camera.allCameras()) do
  watch(cam)
end

-- Cameras come and go (external webcams, Continuity Camera), so also watch the
-- device set itself and attach to anything new.
hs.camera.setWatcherCallback(function(cam, event)
  if event == "Added" then
    watch(cam)
  end
  refresh()
end)
hs.camera.startWatcher()

refresh()
