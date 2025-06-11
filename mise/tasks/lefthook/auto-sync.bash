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

# A script for syncing your environment with the code during certain git hooks. Read
# the comments to learn more about how it works.
#
# Usage:
#   Call this script from the post-merge, post-rewrite, and post-checkout git hooks.
#   Format: <this_script> <git_hook_args>... -- <sync_command>...
#   Example: ./this-script git hook args -- uv sync
#
# Arguments:
#   git_hook_args (required):
#     The arguments that were passed to the git hook.
#   sync_command (required):
#     The command, and its arguments, to run for syncing
#
# Environment Variables:
#   AUTO_SYNC_HOOK_NAME (required):
#     This variable should be set to the name of the git hook that is currently being
#     run. The only supported hooks are 'post-rewrite', 'post-merge', and
#     'post-checkout'.
#   AUTO_SYNC_CHECK_ONLY (optional):
#     If this variable is set to 'true', then instead of actually performing the
#     sync, it will exit with 0 if it would have synced and non-zero otherwise.
#
# Git Config Options:
#   auto-sync.skip.command (optional):
#     A Bash command that determines if sync should be skipped. If it exits with 0,
#     sync will skipped.
#   auto-sync.allow.all (optional):
#     Set this to 'true' if syncing should be allowed on all branches.
#   auto-sync.allow.branch (optional):
#     A list of branches that should be synced.
#
#   Usage:
#     Set a list option with:
#       git config --add <option_name> <option_value>
#     Set a boolean value with:
#       git config <option_name> <true|false>
#     Examples:
#       git config --add auto-sync.skip.branch my-feature-branch
#       git config auto-sync.allow.all true

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
  local should_sync='true'

  local command
  command="$(safe_git_config --get 'auto-sync.skip.command')"
  if [[ -n $command ]] && eval "$command"; then
    should_sync='false'
  fi

  # By default, auto-syncing is only enabled for the default branch since other
  # branches may be a security concern. For example, if you're working on an open
  # source project and your synchronization code can execute arbitrary code, then
  # checking out a pull request that contains malicious synchronization code could
  # compromise your system.
  local should_allow_all_branches
  should_allow_all_branches="$(safe_git_config --get 'auto-sync.allow.all')"
  local is_head_in_allowed_branches
  is_head_in_allowed_branches="$(is_head_in_allowed_branches)"
  if
    [[ $should_allow_all_branches != 'true' && $is_head_in_allowed_branches != 'true' ]]
  then
    should_sync='false'
  fi

  case "${AUTO_SYNC_HOOK_NAME:?}" in
    'post-merge')
      # There's nothing to do in this case
      ;;
    'post-rewrite')
      # Don't run after a commit has been amended
      if [[ $1 == 'amend' ]]; then
        should_sync='false'
      fi
      ;;
    'post-checkout')
      # We should only sync if this is a branch/commit checkout and not a file
      # checkout. The documentation says the third argument to the hook is '1' if
      # it's a branch checkout, but this seems to include checkouts to arbitrary
      # commits as well.
      if (($3 != 1)); then
        should_sync='false'
      fi

      # Don't run when we're in the middle of a pull/rebase, post-merge/post-rewrite
      # will run when the pull/rebase is finished.
      if
        git reflog show --max-count 1 |
          grep -q -E '^.*?: (pull|rebase)( .*?)?: .+'
      then
        should_sync='false'
      fi

      # If the destination commit has been pushed to the default branch, I assume the
      # user is going through the history to debug. As such, we shouldn't sync.
      if git merge-base --is-ancestor "$2" origin/HEAD; then
        should_sync='false'
      fi
      ;;
    *)
      echo "auto-sync: Error, invalid AUTO_SYNC_HOOK_NAME: $AUTO_SYNC_HOOK_NAME" >&2
      exit 1
      ;;
  esac

  exec 1>&$stdout_copy
  echo "$should_sync"
}

function is_head_in_allowed_branches {
  local -a allowed_branches
  local allowed_branches_output
  allowed_branches_output="$(safe_git_config --get-all 'auto-sync.allow.branch')"
  if [[ -n $allowed_branches_output ]]; then
    readarray -t allowed_branches <<<"$allowed_branches_output"
  fi
  # The default branch is always allowed
  allowed_branches+=('origin/HEAD')

  local is_head_in_allowed_branches='false'
  for allowed_branch in "${allowed_branches[@]}"; do
    if git merge-base --is-ancestor HEAD "$allowed_branch"; then
      is_head_in_allowed_branches='true'
      break
    fi
  done

  echo "$is_head_in_allowed_branches"
}

function safe_git_config {
  # If a config option isn't set, git exits with a non-zero code so the `|| true`
  # stops the statement from failing.
  git config "$@" || true
}

main "$@"
