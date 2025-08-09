#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter gnused coreutils
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local -r subcommand="$1"

  local git_directory
  git_directory="$(git rev-parse --absolute-git-dir)"
  local -r faulty_commit="$git_directory/info/recommit-faulty-commit"

  case "$subcommand" in
    'check')
      local -r commit_file="$2"
      local -ra check_command=("${@:3}")

      set +o errexit
      "${check_command[@]}"
      local -r check_command_exit_code=$?
      set -o errexit

      if ((check_command_exit_code != 0)); then
        extract_commit_message "$commit_file" >"$faulty_commit"
      elif [[ -e $faulty_commit ]]; then
        rm "$faulty_commit"
      fi

      exit $check_command_exit_code
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
          exit 1
        fi
      fi

      if [[ $can_restore == 'true' ]]; then
        local temp
        temp="$(mktemp)"

        {
          printf '%s\n\n' "$(<"$faulty_commit")"
          # shellcheck disable=2016
          printf '%s\n%s\n\n%s\n' \
            'The commit restored by `recommit` is above this comment. In case you did not' \
            'want to restore, the original contents of the commit file are below:' \
            "$(<"$commit_file")" |
            # This adds a '#' to the beginning of any lines that don't have one. It's
            # important that all of the commented lines be contiguous so git removes
            # them from the commit message.
            sed 's/^#\?/#/'
        } >"$temp"

        mv "$temp" "$commit_file"
      fi

      if [[ -e $faulty_commit ]]; then
        rm "$faulty_commit"
      fi
      ;;
    *)
      echo "recommit: Error, invalid subcommand: $subcommand" >&2
      exit 2
      ;;
  esac
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
