#!/usr/bin/env bash

# Stop the speakers if the system is about to shut down or sleep.
#
# Apparently, NetworkManager's shutdown is not handled by systemd[1].
# Instead, it shuts itself down after receiving a dbus
# signal from logind. To work around this, I register this script to run before
# NetworkManager turns off any network interface.
#
# [1]: https://unix.stackexchange.com/a/687849
if
	[[ $(systemctl is-system-running) == 'stopping' ]] ||
		grep -q 'suspend now' <<<"$(journalctl --since '10 seconds ago')"
then
	sudo systemctl stop speakers.service
fi
