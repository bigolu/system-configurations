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
  faulty_commit="$(git rev-parse --absolute-git-dir)/info/recommit-faulty-commit"

  case "$subcommand" in
    'check')
      local -r commit_file="$2"
      local -ra check_command=("${@:3}")

      # Only run if there's a line that doesn't start with '#' that has a
      # non-whitespace character. If there are no lines like that, we assume the
      # commit would be aborted.
      if ! grep --quiet --extended-regexp '^([^#[:space:]]|[^#].*[^[:space:]].*)' "$2"; then
        exit 0
      fi

      set +o errexit
      "${check_command[@]}"
      local -r check_command_exit_code=$?
      set -o errexit

      if ((check_command_exit_code != 0)); then
        extract_commit_message "$commit_file" >"$faulty_commit"
      else
        remove_faulty_commit
      fi

      exit "$check_command_exit_code"
      ;;
    'can-restore') ;&
    'restore')
      local -r commit_file="$2"
      local -r commit_source="${3:-}"

      local can_restore
      if [[ -e $faulty_commit && $commit_source != 'message' && $commit_source != 'commit' ]]; then
        can_restore='true'
      else
        can_restore='false'
      fi

      if [[ $subcommand == 'can-restore' ]]; then
        if [[ $can_restore == 'true' ]]; then
          exit 0
        else
          remove_faulty_commit
          exit 1
        fi
      fi

      if [[ $can_restore == 'true' ]]; then
        local temp
        temp="$(mktemp)"

        {
          echo "$(<"$faulty_commit")"
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

      remove_faulty_commit
      ;;
    *)
      echo "recommit: Error, invalid subcommand: $subcommand" >&2
      exit 2
      ;;
  esac
}

function remove_faulty_commit {
  if [[ -e $faulty_commit ]]; then
    rm "$faulty_commit"
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
