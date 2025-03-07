#!/usr/bin/env bash

# Only stop the speakers if the system is being shut down
if [[ $(systemctl is-system-running || true) == 'stopping' ]]; then
  sudo systemctl stop speakers.service
fi
