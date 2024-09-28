set -o errexit
set -o nounset
set -o pipefail

function main {
  message="$1"
  shift

  set_changes_file "$@"

  display_notification "$message"
}

function set_changes_file {
  if git config --get diff.tool 1>/dev/null; then
    write_command_to_file git difftool --no-prompt "$COMMIT_1" "$COMMIT_2" -- "$@"
  else
    write_command_to_file git diff "$COMMIT_1" "$COMMIT_2" -- "$@"
  fi
}

function display_notification {
  # TODO: Workaround since I disable output for successful commands in lefthook,
  # but I can't make an exception for this.
  desktop_notification "$1 (To see the diff run 'just show-changes $DIFF')"

  # echo "$1 (To see the diff run 'just show-changes $DIFF')"
  # if is_in_vscode && ! is_in_vscode_terminal; then
  #   desktop_notification "$1 (Check the VS Code Git/GitLens output panel for details)"
  # fi
}

function desktop_notification {
  local repository_name
  repository_name="$(basename "$PWD")"

  if uname | grep -q Linux; then
    notify-send --app-name "$repository_name" "$1"
  else
    terminal-notifier -title "$repository_name" -message "$1"
  fi
}

function write_command_to_file {
  mkdir -p ".git/change-commands"
  printf '%q ' "$@" >".git/change-commands/$DIFF"
}

function is_in_vscode {
  local tmp=("${!VSCODE_@}")
  [ "${#tmp[@]}" -gt 0 ]
}

function is_in_vscode_terminal {
  [ -n "${VSCODE_INJECTION:-}" ]
}

main "$@"
