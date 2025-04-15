# TODO: Make all electron apps use Wayland instead of X11. This way the apps won't be
# blurry on HiDPI screens. There's an issue[1] for making this the default.
#
# [1]: https://github.com/electron/electron/issues/41551
export ELECTRON_OZONE_PLATFORM_HINT=auto

if [[ -f ~/.config/default-shells/login-config.sh ]]; then
  set -o posix
  # shellcheck disable=1090
  . ~/.config/default-shells/login-config.sh
  set +o posix
fi

# My reason for doing this is at the top of bashrc.bash
if [[ $- == *i* && -f ~/.bashrc ]]; then
  # shellcheck disable=1090
  source ~/.bashrc
fi
