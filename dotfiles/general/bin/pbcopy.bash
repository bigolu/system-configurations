#!/usr/bin/env bash

# This command copies the text from stdin to the clipboard using OSC 52. With this
# you can even copy text from an SSH shell to the host computer's clipboard.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# If we are SSH'd into a remote machine then use the host terminal.
if [[ -n ${SSH_TTY-} ]]; then
  target_tty="$SSH_TTY"
# This conditional checks if this process is connected to a terminal.
# source: https://stackoverflow.com/a/69088164
elif bash -c ": 1>/dev/tty" 1>/dev/null 2>&1; then
  target_tty='/dev/tty'
# If we don't have a terminal to send the escape sequence to, use the system copy
# utility. For example, when neovim is running headless while embedded in another
# editor, like vscode.
else
  if uname | grep -q Linux; then
    if command -v wl-copy 1>/dev/null 2>&1; then
      exec wl-copy
    elif command -v xclip 1>/dev/null 2>&1; then
      exec xclip -selection clipboard
    else
      echo "Error: Can't find the system clipboard copying utility" 1>&2
      exit 127
    fi
  else
    # Full path for the current executable
    my_pbcopy="$0"

    # To find the real pbcopy just take the next pbcopy binary on the $PATH after
    # this one. This way if there are other wrappers they can do the same and
    # eventually we'll reach the real pbcopy.
    reached_wrapper=''
    real_pbcopy=''
    which_pbcopy_output="$(which -a pbcopy)"
    readarray -t all_pbcopys <<<"$which_pbcopy_output"
    for command in "${all_pbcopys[@]}"; do
      if [[ $my_pbcopy == "$command" ]]; then
        reached_wrapper=1
      elif [[ -n $reached_wrapper ]]; then
        real_pbcopy="$command"
        break
      fi
    done

    if [[ -n $real_pbcopy ]]; then
      exec "$real_pbcopy"
    else
      echo "Error: Can't find the system pbcopy" 1>&2
      exit 127
    fi
  fi
fi

# Get input from stdin
#
# Command substitution removes trailing newlines, but I want to keep them. To do so,
# I add a character to the end of the input, this way any trailing newlines will no
# longer be trailing. Then I remove the extra character by getting a substring that
# excludes the last character.
input="$(
  cat
  printf x
)"
input="${input::-1}"

inputlen=$(printf '%s' "$input" | wc -c)

# https://sunaku.github.io/tmux-yank-osc52.html
# The maximum length of an OSC 52 escape sequence is 100_000 bytes, of which
# 7 bytes are occupied by a "\033]52;c;" header, 1 byte by a "\a" footer, and
# 99_992 bytes by the base64-encoded result of 74_994 bytes of copyable text
maxlen=74994

# warn if exceeds maxlen
if [[ $inputlen -gt $maxlen ]]; then
  printf "input is %d bytes too long" "$((inputlen - maxlen))" >&2
fi

# build up OSC 52 ANSI escape sequence
esc="\033]52;c;$(printf '%s' "$input" | head -c $maxlen | base64 | tr -d '\r\n')\a"

printf %b "$esc" >"$target_tty"
