#!/usr/bin/env bash

# Only stop the speakers if the system is about to shut down or sleep.
if
  [[ $(systemctl is-system-running || true) == 'stopping' ]] ||
    grep -q 'suspend' <<<"$(journalctl --since '10 seconds ago' || true)"
then
  sudo systemctl stop speakers.service
fi
