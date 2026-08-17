-- modules/usbconsole.lua
--
-- When a USB serial adapter is plugged in, offer to open a console session in
-- Ghostty instead of you hunting for the right /dev/tty.* path and remembering
-- the picocom incantation.
--
-- Match on productName substrings; run `hs.usb.attachedDevices()` in the
-- Hammerspoon console with your adapter plugged in to find the right string.

local ADAPTER_PATTERNS = {
  "USB.*Serial",
  "FT232",
  "CP210",
  "UART",
  "Prolific",
}

local BAUD = "9600"

local function isAdapter(name)
  if not name then return false end
  for _, pat in ipairs(ADAPTER_PATTERNS) do
    if name:match(pat) then return true end
  end
  return false
end

-- Pick the most recently created /dev/tty.usb* device.
local function newestTTY()
  local out = hs.execute("/bin/ls -t /dev/tty.usb* 2>/dev/null | /usr/bin/head -1")
  out = (out or ""):gsub("%s+$", "")
  if out == "" then return nil end
  return out
end

local function openConsole()
  local tty = newestTTY()
  if not tty then
    hsutil.toast("Serial adapter attached\nno /dev/tty.usb* yet", 3)
    return
  end

  -- Ghostty honours -e to run a command in a new window.
  hs.task.new("/usr/bin/open", nil, {
    "-na", "Ghostty", "--args", "-e", string.format("picocom -b %s %s", BAUD, tty),
  }):start()

  hsutil.toast("🔌 console: " .. tty:gsub("^/dev/", ""), 3)
end

local watcher = hs.usb.watcher.new(function(dev)
  if dev.eventType ~= "added" then return end
  if not isAdapter(dev.productName) then return end

  -- Give the kernel a moment to create the tty node.
  hs.timer.doAfter(1.2, function()
    local choice = hs.dialog.blockAlert(
      "Serial adapter detected",
      (dev.productName or "adapter") .. "\n\nOpen a picocom session?",
      "Open", "Ignore"
    )
    if choice == "Open" then
      openConsole()
    end
  end)
end)

watcher:start()

return watcher
