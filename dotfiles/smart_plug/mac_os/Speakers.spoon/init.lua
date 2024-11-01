local ThingsThatShouldNotBeGarbageCollected = {}

local function execute(executable, arguments, callback)
  -- I'm using hs.task because os.execute was really slow[1].
  --
  -- [1]: https://github.com/Hammerspoon/hammerspoon/issues/2570
  return hs.task.new(executable, callback, arguments):start()
end

local function get_command_output(executable, arguments, callback)
  execute(executable, arguments, function(_, stdout, _)
    -- TODO: I think this also trims leading newlines:
    -- https://stackoverflow.com/a/51181334
    local trimmed = string.gsub(stdout, "^%s*(.-)%s*$", "%1")
    callback(trimmed)
  end)
end

local function listen(speakerctl_path)
  local function turn_on()
    execute(speakerctl_path, { "on" })
  end

  local function turn_off()
    execute(speakerctl_path, { "off" })
  end

  local function is_laptop_docked()
    local exit_code = execute("/bin/sh", {
        "-c",
        [[system_profiler SPUSBDataType | grep -q 'OWC Thunderbolt']],
      })
      :waitUntilExit()
      :terminationStatus()

    return exit_code == 0
  end

  local watcher = hs.caffeinate.watcher
  ThingsThatShouldNotBeGarbageCollected.watcher = watcher
    .new(function(event)
      if not is_laptop_docked() then
        return
      end

      if
        hs.fnutils.contains({
          watcher.screensDidLock,
          watcher.screensaverDidStart,
          watcher.screensDidSleep,
          watcher.systemWillPowerOff,
          watcher.systemWillSleep,
        }, event)
      then
        turn_off()
      elseif
        hs.fnutils.contains({
          watcher.screensDidUnlock,
          watcher.screensaverDidStop,
          watcher.screensDidWake,
          watcher.systemDidWake,
        }, event)
      then
        turn_on()
      end
    end)
    :start()

  -- If the computer is docked before I turn it on, then hammerspoon won't start
  -- until I've already logged in so the speakers won't turn on. To get around
  -- that, I'll turn them on now.
  if is_laptop_docked() then
    turn_on()
  end
end

-- Using an interactive-login shell to make sure Nix's shell configuration runs so I
-- can find `speakerctl`.
get_command_output("/usr/bin/env", {
  "HAMMERSPOON_RESOLVING_ENVIRONMENT=1",
  os.getenv("SHELL"),
  "-l",
  "-i",
  "-c",
  [[command -v speakerctl]],
}, listen)

return ThingsThatShouldNotBeGarbageCollected
