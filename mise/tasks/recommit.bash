#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter gnused coreutils gnugrep
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local -r subcommand="$1"

  # Intentionally global
  backup="$(git rev-parse --absolute-git-dir)/info/recommit-message-backup"

  case "$subcommand" in
    'clear')
      clear_backup
      ;;
    'backup')
      local -r commit_file="$2"
      # Only backup if there's a line that doesn't start with '#' that has a
      # non-whitespace character. If there are no lines like that, we assume the
      # commit would be aborted due to an empty message and as such, the post-commit
      # hook would not run so we wouldn't remove our backup.
      if grep --quiet --extended-regexp '^([^#[:space:]]|[^#].*[^[:space:]].*)' "$2"; then
        extract_commit_message "$commit_file" >"$backup"
      fi
      ;;
    'can-restore') ;&
    'restore')
      local -r commit_file="$2"
      local -r commit_source="${3:-}"

      local can_restore
      if [[ -e $backup && $commit_source != 'message' && $commit_source != 'commit' ]]; then
        can_restore='true'
      else
        can_restore='false'
      fi

      if [[ $subcommand == 'can-restore' ]]; then
        if [[ $can_restore == 'true' ]]; then
          exit 0
        else
          clear_backup
          exit 1
        fi
      fi

      if [[ $can_restore == 'true' ]]; then
        local temp
        temp="$(mktemp)"

        {
          echo "$(<"$backup")"
          {
            # shellcheck disable=2016
            echo ' (This commit message was restored by `recommit`)'
            echo "$(<"$commit_file")"
          } |
            # This ensures all lines are comments since git only removes contiguous
            # commented lines.
            sed 's/^#\?/#/'
        } >"$temp"

        mv "$temp" "$commit_file"
      fi

      clear_backup
      ;;
    *)
      echo "recommit: Error, invalid subcommand: $subcommand" >&2
      exit 2
      ;;
  esac
}

function clear_backup {
  if [[ -e $backup ]]; then
    rm "$backup"
  fi
}

function extract_commit_message {
  local -r commit_file="$1"

  # The first expression removes the diff added by `git commit --verbose`. The second
  # one removes any commented lines.
  sed \
    --expression '/# ------------------------ >8 ------------------------/,$d' \
    --expression '/^#/d' \
    "$commit_file"
}

main "$@"
