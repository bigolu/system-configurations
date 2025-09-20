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

  local -r program_name='commit-message-backup'

  local backup
  backup="$(git rev-parse --absolute-git-dir)/info/$program_name"

  case "$subcommand" in
    'remove')
      remove "$backup"
      ;;
    'create')
      local -r commit_file="$2"
      # Only make a backup if there's a line that doesn't start with '#' that has a
      # non-whitespace character. If there are no lines like that, we assume the
      # commit would be aborted due to an empty message and as such, the post-commit
      # hook would not run so we wouldn't remove our backup.
      #
      # The pattern to the left of the `|` matches lines with a single non-whitespace
      # character and the pattern on the right matches lines with multiple whitespace
      # characters.
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
          remove "$backup"
          exit 1
        fi
      fi

      if [[ $can_restore == 'true' ]]; then
        # Ensure all lines are comments since git only removes contiguous commented
        # lines.
        local commented_commit_file_contents
        commented_commit_file_contents="$(sed 's/^#\?/#/' <"$commit_file")"

        printf '%s\n' \
          "$(<"$backup")" \
          "# (This commit message was restored by \`$program_name\`)" \
          "$commented_commit_file_contents" \
          >"$commit_file"
      fi

      remove "$backup"
      ;;
    *)
      echo "$program_name: Error, invalid subcommand: $subcommand" >&2
      exit 2
      ;;
  esac
}

function remove {
  local -r backup="$1"
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
