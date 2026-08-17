-- modules/urldispatch.lua
--
-- Route links by hostname instead of having one "default browser".
-- Work hosts -> work Chrome profile. Everything else -> Safari.
--
-- REQUIRES: set Hammerspoon as the system default browser
--   System Settings > Desktop & Dock > Default web browser > Hammerspoon
-- Until you do that, this module is inert (it will simply never be called).
--
-- Find your Chrome profile directory names under:
--   ~/Library/Application Support/Google/Chrome/  ("Default", "Profile 1", ...)
--
-- The actual work hostnames are machine-specific and deliberately NOT tracked:
-- they live in ~/.hammerspoon/local.lua (gitignored), which returns a table:
--
--   return {
--     work_profile = "Default",
--     work_hosts = {           -- Lua patterns, so `.` is escaped as `%.`
--       "gitlab%.example%.com",
--       "%.internal%.example%.",
--     },
--   }

local CHROME = "/Applications/Google Chrome.app"
local FALLBACK = "com.apple.Safari"

local ok, localcfg = pcall(require, "local")
if not ok then localcfg = {} end

local WORK_PROFILE = localcfg.work_profile or "Default"

-- Generic patterns that are work-shaped on most infra jobs; the employer's
-- own hostnames come from local.lua and are appended below.
local WORK_HOSTS = {
  "atlassian%.net",
  "%.atlassian%.com",
  "grafana",
  "netbox",
}
for _, pat in ipairs(localcfg.work_hosts or {}) do
  table.insert(WORK_HOSTS, pat)
end

local function isWork(host)
  if not host then return false end
  host = host:lower()
  for _, pat in ipairs(WORK_HOSTS) do
    if host:match(pat) then return true end
  end
  return false
end

local function openInChromeProfile(url, profile)
  hs.task.new("/usr/bin/open", nil, {
    "-na", CHROME, "--args", "--profile-directory=" .. profile, url,
  }):start()
end

hs.urlevent.httpCallback = function(_, host, _, fullURL)
  if isWork(host) then
    openInChromeProfile(fullURL, WORK_PROFILE)
  else
    hs.urlevent.openURLWithBundle(fullURL, FALLBACK)
  end
end
