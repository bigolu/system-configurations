# TODO: Make electron apps use Wayland, instead of using xwayland. This way the
# font won't be blurry on HiDPI screens. There's an issue[1] for making this the
# default.
#
# [1]: https://github.com/electron/electron/issues/41551
export ELECTRON_OZONE_PLATFORM_HINT=auto

# My reason for doing this is at the top of bashrc.bash
if [[ $- == *i* && -f ~/.bashrc ]]; then
  # shellcheck disable=1090
  source ~/.bashrc
fi
