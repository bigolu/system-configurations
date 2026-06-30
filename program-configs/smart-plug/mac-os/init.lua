-- This lets you use the hammerspoon commandline tool
require("hs.ipc")
hs.ipc.cliInstall()

-- Create annotations that a language server could use to provide documentation,
-- autocomplete, etc.
hs.loadSpoon("EmmyLua", false)

local speakerctl = [[@speakerctl@]]

local garbage_collector_roots = {}

local function execute(executable, arguments, callback)
	-- I'm using hs.task because it's faster than os.execute[1].
	--
	-- [1]: https://github.com/Hammerspoon/hammerspoon/issues/2570
	return hs.task.new(executable, callback, arguments):start()
end

local function turn_on()
	execute(speakerctl, { "on" })
end

local function turn_off()
	execute(speakerctl, { "off" })
end

local function is_laptop_docked()
	local exit_code = execute("/usr/bin/env", {
			"sh",
			"-c",
			[[system_profiler SPUSBDataType | grep -q 'High-Speed hub']],
		})
		:waitUntilExit()
		:terminationStatus()

	return exit_code == 0
end

local hs_watcher = hs.caffeinate.watcher
local watcher = hs_watcher.new(function(event)
	if not is_laptop_docked() then
		return
	end

	if
		hs.fnutils.contains({
			hs_watcher.screensDidLock,
			hs_watcher.screensaverDidStart,
			hs_watcher.screensDidSleep,
			hs_watcher.systemWillPowerOff,
			hs_watcher.systemWillSleep,
		}, event)
	then
		turn_off()
	elseif
		hs.fnutils.contains({
			hs_watcher.screensDidUnlock,
			hs_watcher.screensaverDidStop,
			hs_watcher.screensDidWake,
			hs_watcher.systemDidWake,
		}, event)
	then
		turn_on()
	end
end)
watcher:start()
table.insert(garbage_collector_roots, watcher)

-- If the computer is docked before I turn it on, then hammerspoon won't start
-- until I've already logged in so the speakers won't turn on. To get around
-- that, I'll turn them on now.
if is_laptop_docked() then
	turn_on()
end

return garbage_collector_roots
