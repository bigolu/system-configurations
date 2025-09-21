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
      if [[ -e $backup && $commit_source != 'message' ]]; then
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

        # When `commit_source` is 'commit', we know `--amend` was provided, but we
        # don't know if `--no-edit` was provided. We only want to restore if
        # `--no-edit` wasn't provided. As a workaround, we will restore the backed up
        # message as a comment. This way, if `--no-edit` was provided, the backed up
        # message won't be used. If `--no-edit` wasn't provided, the user can take
        # the restored message out of the comment themselves.
        #
        # TODO: See if git can let the prepare-commit-msg hook know if `--no-edit`
        # was provided.
        if [[ $commit_source == 'commit' ]]; then
          commit_file_contents="$(<"$commit_file")"
          did_insert='false'
          while IFS= read -r line; do
            # Insert the restored message just before the comment starts in the
            # commit file.
            if [[ $line == '#'* && $did_insert != 'true' ]]; then
              printf '%s\n' \
                "# Below is the commit message restored by \`$program_name\`:" \
                "$(<"$backup")" \
                '#' |
                # Ensure all lines are comments since git only removes contiguous
                # commented lines.
                sed 's/^#\? \?/# /'
              did_insert='true'
            fi
            echo "$line"
          done <<<"$commit_file_contents" >"$commit_file"
        else
          # Ensure all lines are comments since git only removes contiguous commented
          # lines.
          local commented_commit_file_contents
          commented_commit_file_contents="$(sed 's/^#\? \?/# /' <"$commit_file")"

          printf '%s\n' \
            "$(<"$backup")" \
            "# (Commit message restored by \`$program_name\`)" \
            "$commented_commit_file_contents" \
            >"$commit_file"
        fi
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
