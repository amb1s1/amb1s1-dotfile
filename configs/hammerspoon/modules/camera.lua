-- modules/camera.lua
--
-- Turn the focused-window border red whenever any camera is in use, so "am I
-- live?" is answerable from peripheral vision instead of hunting for the
-- meeting window. Restores your normal colour when the camera releases.
--
-- This is the canonical example of something only Hammerspoon can do:
-- hs.camera exposes per-device in-use state, which no config-file tool offers.

local NORMAL_ACTIVE = "0xffdfff52"  -- keep in sync with .aerospace.toml
local ON_AIR_ACTIVE = "0xffff5555"

local function anyCameraInUse()
  for _, cam in ipairs(hs.camera.allCameras()) do
    if cam:isInUse() then return true end
  end
  return false
end

local function refresh()
  if anyCameraInUse() then
    hsutil.borders({ "active_color=" .. ON_AIR_ACTIVE })
    hsutil.toast("🔴 camera on", 1)
  else
    hsutil.borders({ "active_color=" .. NORMAL_ACTIVE })
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
