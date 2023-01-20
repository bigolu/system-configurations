#!/bin/env sh

# Exit if a command returns a non-zero exit code
set -o errexit

# Exit if an unset variable is referenced
set -o nounset

# Exit if this OS is not Linux
if uname | grep -q -i -v linux; then
  exit
fi

# On apple keyboards, use media keys when a Function key is pressed without the Fn modifier key
APPLE_KEYBOARD_CONF='/etc/modprobe.d/hid_apple.conf'
if [ ! -f "$APPLE_KEYBOARD_CONF" ] || grep -q 'hid_apple fnmode=1' < "$APPLE_KEYBOARD_CONF"; then
  echo options hid_apple fnmode=1 | sudo tee -a /etc/modprobe.d/hid_apple.conf
  sudo update-initramfs -u -k all
fi