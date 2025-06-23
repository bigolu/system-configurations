#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter git]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# A script that automatically syncs your environment with the code during certain
# git hooks.
#
# Usage:
#   Call this script from the post-merge, post-rewrite, post-checkout, and
#   post-commit git hooks.
#     Format: auto-sync <git_hook_args>... -- <sync_command>...
#     Example: auto-sync git hook args -- uv sync
#   NOTE: When you call it from the post-commit hook, you don't have to provide any
#   arguments.
#     Example: auto-sync
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
#     run. The only supported hooks are post-rewrite, post-merge, post-checkout, and
#     post-commit.
#   AUTO_SYNC_CHECK_ONLY (optional):
#     If this variable is set to 'true', then instead of performing the sync, it will
#     exit with 0 if it would have synced and non-zero otherwise.
#
# Environment Variables Set by auto-sync:
#   AUTO_SYNC_LAST_COMMIT:
#     This variable will be set to the hash of last synced commit or an empty string
#     if no commit has been synced. This can be used by the sync command to calculate
#     the files that differ between a new commit that's being synced with and the
#     last one. Then it can use this file list to more granularly determine what
#     needs to be synced.
#
# Git Config Options:
#   auto-sync.allow.all (optional):
#     Set this to 'true' if syncing should be allowed on all branches.
#
#   Usage:
#     git config auto-sync.allow.all true
#
# [1]: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html#index-_005b_005b

if [[ ${AUTO_SYNC_DEBUG:-} == 'true' ]]; then
  echo "AUTO_SYNC_HOOK_NAME: ${AUTO_SYNC_HOOK_NAME:?}"
  echo "Last reflog entry: $(git --no-pager reflog show --max-count 1 || true)"
  set -o xtrace
fi

function main {
  # We'll consider the repository synced with any commit made locally.
  if
    [[ $AUTO_SYNC_HOOK_NAME == 'post-commit' ]] ||
      {
        [[ $AUTO_SYNC_HOOK_NAME == 'post-rewrite' ]] &&
          [[ $1 == 'amend' ]]
      }
  then
    track_last_synced_commit
    exit
  fi

  should_sync="$(should_sync "$@")"

  if [[ ${AUTO_SYNC_CHECK_ONLY:-} == 'true' ]]; then
    if [[ $should_sync == 'true' ]]; then
      exit 0
    else
      exit 1
    fi
  fi

  if [[ $should_sync == 'true' ]]; then
    # Even if the sync doesn't succeed, we still want to consider the repository
    # synced against the current commit since the user will probably fix whatever
    # wasn't working and rerun the sync.
    trap track_last_synced_commit EXIT

    local -a sync_command
    local seen_delimiter='false'
    for arg in "$@"; do
      if [[ $seen_delimiter == 'true' ]]; then
        sync_command+=("$arg")
      elif [[ $arg == '--' ]]; then
        seen_delimiter='true'
      fi
    done

    local last_commit
    last_commit="$(get_last_commit)"

    AUTO_SYNC_LAST_COMMIT="$last_commit" "${sync_command[@]}"
  fi
}

function track_last_synced_commit {
  local last_commit_path
  last_commit_path="$(get_last_commit_path)"
  git rev-parse HEAD >"$last_commit_path"
}

function get_last_commit_path {
  local git_directory
  git_directory="$(git rev-parse --absolute-git-dir)"
  echo "$git_directory/info/auto-sync-last-commit"
}

function get_last_commit {
  local last_commit_path
  last_commit_path="$(get_last_commit_path)"
  if [[ -e $last_commit_path ]]; then
    echo "$(<"$last_commit_path")"
  fi
}

function should_sync {
  # Redirect stdout to stderr until we're ready to print the result. This way, if any
  # commands we execute happen to print to stdout, the caller won't capture it.
  exec {stdout_copy}>&1
  exec 1>&2
  local should_sync='true'

  local last_commit
  last_commit="$(get_last_commit)"
  # If there are no differences between the last commit we synced with and the
  # current one, then we shouldn't sync.
  if
    [[ -n $last_commit ]] &&
      git diff --exit-code --quiet "$last_commit" HEAD
  then
    should_sync='false'
  fi

  local last_reflog_entry
  last_reflog_entry="$(git reflog show --max-count 1)"

  # By default, auto-syncing is only enabled for the default branch since other
  # branches may be a security concern. For example, if you're working on an open
  # source project and your synchronization code can execute arbitrary code, then
  # checking out a pull request that contains malicious synchronization code could
  # compromise your system.
  #
  # The exception to this is a non-pull merge/rebase. I assume that those are ok
  # since I only expect people to do a merge/rebase on a branch they trust, unless
  # it's part of a pull. For example, rebasing a feature branch on master.
  local should_allow_all_branches
  should_allow_all_branches="$(safe_git_config --get 'auto-sync.allow.all')"
  local is_head_in_default_branch
  is_head_in_default_branch="$(is_head_in_default_branch)"
  local -r pull_regex='^.*: pull( .*)?: .+'
  if
    [[ $should_allow_all_branches != 'true' && $is_head_in_default_branch != 'true' ]] &&
      ! {
        [[ $AUTO_SYNC_HOOK_NAME == 'post-merge' || $AUTO_SYNC_HOOK_NAME == 'post-rewrite' ]] &&
          [[ ! $last_reflog_entry =~ $pull_regex ]]
      }
  then
    should_sync='false'
  fi

  # Disable sync in scenarios where the user probably doesn't want to run it.
  case "${AUTO_SYNC_HOOK_NAME:?}" in
    'post-merge')
      # There's nothing to do in this case
      ;;
    'post-rewrite')
      # There's nothing to do in this case
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
      local -r pull_rebase_regex='^.*: (pull|rebase)( .*)?: .+'
      if [[ $last_reflog_entry =~ $pull_rebase_regex ]]; then
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

function is_head_in_default_branch {
  local default_branch
  default_branch="$(get_default_branch)"

  if git merge-base --is-ancestor HEAD "$default_branch"; then
    echo 'true'
  else
    echo 'false'
  fi
}

function get_default_branch {
  local default_branch_path
  default_branch_path="$(git symbolic-ref refs/remotes/origin/HEAD)"
  # This gets the characters after the last '/'. `default_branch_path` will resemble
  # 'refs/remotes/origin/master' so this would return 'master'.
  echo "${default_branch_path##*/}"
}

function safe_git_config {
  # If a config option isn't set, git exits with a non-zero code so the `|| true`
  # stops the statement from failing.
  git config "$@" || true
}

main "$@"
