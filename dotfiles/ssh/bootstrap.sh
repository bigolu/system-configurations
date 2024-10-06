# shellcheck shell=sh

set -o errexit
set -o nounset

trap '[ $? -ne 0 ] && printf "%s\n" "Bootstrap failed, falling back to a login shell..." >&2 && exec "$SHELL" -l' EXIT

abort() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

if command -v base64 1>/dev/null 2>&1; then
  base64_decode() {
    base64 -d
  }
else
  # Taken from here:
  # https://github.com/ko1nksm/sh-base64
  base64_decode() {
    set -- "${1:-"+/="}" && set -- "${1%=}" "${1#??}"
    set -- "$@" "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    LC_ALL=C fold -b -w100 | { # fold width must be a multiple of 4
      # workaround for nawk: https://github.com/onetrueawk/awk/issues/38
      [ "$2" = '=' ] && set -- "$1" '\075' "$3"
      LC_ALL=C awk -v x="$3$1" -v p="$2" '
        function dec2bin(n, w,  r) {
          for (r = ""; n > 0; n = int(n / 2)) r = (n % 2) r
          return sprintf("%0" w "d", r)
        }
        BEGIN {
          # Process in pairs of two characters for better performance
          for (i = 0; i < 64; i++) {
            ik = substr(x, i + 1, 1); iv = dec2bin(i, 6); b[ik] = b[ik p] = iv
            for (j = 0; j < 64; j++) b[ik substr(x, j + 1, 1)] = iv dec2bin(j, 6)
          }

          for (i = 1; i < 256; i++) c[dec2bin(i, 8)] = sprintf("%c", i)
          c["00000000"] = "\\\\000"; c["00001001"] = "\\\\011" # NUL HT
          c["00001010"] = "\\\\012"; c["00001011"] = "\\\\013" # LF  VT
          c["00001100"] = "\\\\014"; c["00001101"] = "\\\\015" # FF  CR
          c["00100000"] = "\\\\040"; c["00100010"] = "\\\\042" # SPC DQ
          c["00100101"] = "\\\\045"; c["00100111"] = "\\\\047" # %   SQ
          c["01011100"] = "\\\\\\\\"
        }
        {
          len = length($0); bits = chars = ""
          for (i = 1; i <= len; i+=2) bits = bits b[substr($0, i, 2)]
          for (i = 1; i <= len * 6; i+=8) chars = chars c[substr(bits, i, 8)]
          print chars
        }
      '
    } | (
      # shellcheck disable=2016
      for_mksh='[ ${KSH_VERSION:+x} ] && alias printf="print -n";'
      code='IFS=; printf -- "$*"' prog="${ZSH_ARGZERO:-"$0"}"
      LC_ALL=C xargs -n 1000 -E '' sh -c "${for_mksh}${code}" "$prog"
    )
  }
fi

[ -z "$BIGOLU_TERMINFO" ] && abort 'No terminfo was provided'
[ -z "$BIGOLU_TERMCAP" ] && abort 'No termcap was provided'

prefix="$HOME/.cache/bigolu"
if ! mkdir -p "$prefix"; then
  prefix="/tmp/bigolu-cache"
  if ! mkdir -p "$prefix"; then
    abort "Unable to create a prefix"
  fi
fi

install_terminfo() {
  # TODO: I wonder if it's more portable to put a file path in here
  TERMCAP="$(printf "%s" "$BIGOLU_TERMCAP" | base64_decode)"
  export TERMCAP
  # TODO: The newlines have been removed from the termcap so it can be put in an environment
  # variable and I'm not sure if I need to add them back now that I'm putting it in a file.
  printf '%s' "$TERMCAP" >"$prefix/termcap"
  export TERMPATH="$prefix/termcap"

  # TODO: I wonder if it's more portable to put a file path in here
  export TERMINFO="$BIGOLU_TERMINFO"

  first_letter="$(printf '%.1s' "$TERM")"
  first_letter_as_hex="$(printf '%x' "'$first_letter")"
  char_terminfo_path="$prefix/terminfo/$first_letter"
  hex_terminfo_path="$prefix/terminfo/$first_letter_as_hex"
  mkdir -p "$char_terminfo_path"
  mkdir -p "$hex_terminfo_path"
  # The `cut` removes the first 4 letters 'b64:'
  printf '%s' "$TERMINFO" | cut -c 5- | base64_decode >"$char_terminfo_path/$TERM"
  cp "$char_terminfo_path/$TERM" "$hex_terminfo_path/$TERM"
  export TERMINFO_DIRS="$prefix/terminfo"
}

show_free_space() {
  printf '%s\n%s\n' 'Disk Usage' '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

  # -h isn't POSIX so don't count on it
  df -h 2>/dev/null || df

  # separator line
  echo
}

install_terminfo

export BIGOLU_BOOTSTRAP_PREFIX="$prefix"

exec "$SHELL" -l
