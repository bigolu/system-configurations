set -o errexit
set -o nounset
set -o pipefail

function main {
  repository_name="$(basename "$PWD")"

  vscode_environment_variables=("${!VSCODE_@}")
  # If VSCODE_INJECTION is set we are in the VS Code terminal, in which case we
  # still want the terminal backend.
  if [ "${#vscode_environment_variables[@]}" -gt 0 ] && [ -z "${VSCODE_INJECTION:-}" ]; then
    vscode "$@"
  else
    terminal "$@"
  fi
}

function vscode {
  if [ -n "${DIFF:-}" ]; then
    desktop_notification "$1"' (Check the git output panel in VS Code for a diff of the changes)'
    set -- "${@:2}"

    # Pipe to cat so if you're at the terminal, it doesn't launch a full screen
    # pager that you'd have to eit.
    #
    # Remove colors since VS Code's output panel doesn't support them
    git diff --color never ORIG_HEAD HEAD -- "$@" | cat
  else
    desktop_notification "$1"
  fi
}

function terminal {
  if [ -n "${DIFF:-}" ]; then
    echo -e "$1"
    set -- "${@:2}"

    # Pipe to cat so if you're at the terminal, it doesn't launch a full screen
    # pager that you'd have to eit.
    git diff --color ORIG_HEAD HEAD -- "$@" | cat
  else
    echo -e "$@"
  fi
}

function desktop_notification {
  if uname | grep -q Linux; then
    notify-send --app-name "$repository_name" "$1"
  else
    terminal-notifier -title "$repository_name" -message "$1"
  fi
}

main "$@"
