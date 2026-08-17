-- modules/wifi.lua
--
-- Announce which network you are on when it changes, and classify it into a
-- trust zone. For anyone who works across corp / home / untrusted networks,
-- the useful signal is not "wifi changed" but "which zone am I in now".
--
-- SSID lists are machine-specific and untracked: define them in
-- ~/.hammerspoon/local.lua (gitignored), e.g.
--
--   return {
--     trusted_ssids = { ["Home-5G"] = true },
--     corp_ssids    = { ["Corp-WiFi"] = true },
--   }
--
-- Anything unmatched is UNTRUSTED.

local ok, localcfg = pcall(require, "local")
if not ok then localcfg = {} end

local TRUSTED = localcfg.trusted_ssids or {}
local CORP = localcfg.corp_ssids or {}

local function zoneFor(ssid)
  if ssid == nil then return "OFFLINE", "🔌" end
  if CORP[ssid] then return "CORP", "🏢" end
  if TRUSTED[ssid] then return "TRUSTED", "🏠" end
  return "UNTRUSTED", "⚠️"
end

local lastSSID = hs.wifi.currentNetwork()

local watcher = hs.wifi.watcher.new(function()
  local ssid = hs.wifi.currentNetwork()
  if ssid == lastSSID then return end
  lastSSID = ssid

  local zone, icon = zoneFor(ssid)
  hsutil.toast(string.format("%s  %s\n%s", icon, ssid or "disconnected", zone), 3)

  -- Hook point: react to the zone rather than the SSID.
  -- Example (left commented deliberately — enable once you have decided the
  -- policy you actually want):
  --
  -- if zone == "UNTRUSTED" then
  --   hs.execute("/opt/homebrew/bin/tailscale up", true)
  -- end
end)

watcher:start()

return watcher
