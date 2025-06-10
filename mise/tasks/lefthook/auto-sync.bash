#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter git coreutils gnused]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Usage: <this_script> <git_hook_args>... -- <sync_command>...
#
# Arguments:
#   git_hook_args (required):
#     The arguments that were passed to the git hook.
#   sync_command (required):
#     The command, and its arguments, to run for syncing
#
# Environment Variables
#   AUTO_SYNC_HOOK_NAME (required):
#     This variable should be set to the name of the git hook that is currently being
#     run. The only supported hooks are 'post-rewrite', 'post-merge', and
#     'post-checkout'.
#   AUTO_SYNC_CHECK_ONLY (optional):
#     If this variable is set to 'true', then instead of actually performing the
#     sync, it will exit with 0 if it would have synced and non-zero otherwise.

function main {
  should_sync="$(should_sync "$@")"

  if [[ ${AUTO_SYNC_CHECK_ONLY:-} == 'true' ]]; then
    if [[ $should_sync == 'true' ]]; then
      exit 0
    else
      exit 1
    fi
  fi

  if [[ $should_sync == 'true' ]]; then
    get_sync_command "$@" |
      {
        readarray -d '' sync_command
        "${sync_command[@]}"
      }
  fi
}

function get_sync_command {
  local seen_delimiter='false'
  for arg in "$@"; do
    if [[ $seen_delimiter == 'true' ]]; then
      printf '%s\0' "$arg"
    elif [[ $arg == '--' ]]; then
      seen_delimiter='true'
    fi
  done
}

function should_sync {
  # Redirect stdout to stderr until we're ready to print the result. This way, if any
  # commands we execute happen to print to stdout, the caller won't capture it.
  exec {stdout_copy}>&1
  exec 1>&2
  local result='true'

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"

  # User-Specified, branch-based skips
  local output
  # If the config option isn't set, git returns a non-zero code so the `|| true`
  # stops it from failing.
  output="$(git config --get-all "auto-sync.skip.${AUTO_SYNC_HOOK_NAME:?}.branch" || true)"
  local -a branches
  if [[ -n $output ]]; then
    readarray -t branches <<<"$output"
    for branch in "${branches[@]}"; do
      if [[ $branch == "$current_branch" ]]; then
        result='false'
      fi
    done
  fi

  # User-Specified, command-based skips
  #
  # If the config option isn't set, git returns a non-zero code so the `|| true`
  # stops it from failing.
  output="$(git config --get-all "auto-sync.skip.$AUTO_SYNC_HOOK_NAME.command" || true)"
  local -a commands
  if [[ -n $output ]]; then
    readarray -t commands <<<"$output"
    for command in "${commands[@]}"; do
      if eval "$command"; then
        result='false'
      fi
    done
  fi

  # By default, auto-syncing is only enabled for the default branch since other
  # branches may be a security concern. For example, if you're working on an open
  # source project and your synchronization code can execute arbitrary code, then
  # checking out a pull request that contains malicious synchronization code could
  # compromise your system.
  local default_branch
  default_branch="$(
    LC_ALL='C' git remote show origin |
      sed -n '/HEAD branch/s/.*: //p'
  )"
  if
    ! {
      # The `|| ...` serves two purposes:
      #   - If the config option isn't set, git returns a non-zero code, but the
      #     `|| ...` stops it from failing.
      #   - It provides a default value
      git config --get-all 'auto-sync.allowed-branches' ||
        echo "$default_branch"
    } |
      # If none of the allowed branches are the current branch or the special value
      # "all", we shouldn't sync.
      grep -q -E "^($current_branch|all)\$"
  then
    result='false'
  fi

  case "$AUTO_SYNC_HOOK_NAME" in
    'post-merge')
      # There's nothing to do in this case
      ;;
    'post-rewrite')
      # Don't run after a commit has been amended
      if [[ $1 == 'amend' ]]; then
        result='false'
      fi
      ;;
    'post-checkout')
      # We should only sync if this is a branch/commit checkout and not a file
      # checkout. The documentation says the third argument to the hook is '1' if
      # it's a branch checkout, but this seems to include checkouts to arbitrary
      # commits as well.
      if (($3 != 1)); then
        result='false'
      fi

      # Don't run when we're in the middle of a pull/rebase, post-merge/post-rewrite
      # will run when the pull/rebase is finished.
      if
        git reflog show --max-count 1 |
          grep -q -E '^.*?: (pull|rebase)( .*?)?: .+'
      then
        result='false'
      fi

      # If the destination commit has been pushed to the default branch, I assume the
      # user is going through the history to debug. As such, we shouldn't sync.
      if git merge-base --is-ancestor "$2" origin/HEAD; then
        result='false'
      fi
      ;;
    *)
      echo "Error, invalid AUTO_SYNC_HOOK_NAME: $AUTO_SYNC_HOOK_NAME" >&2
      exit 1
      ;;
  esac

  exec 1>&$stdout_copy
  echo "$result"
}

main "$@"
