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

# A script for syncing your environment with the code during certain git hooks. Read
# the comments to learn more about how it works.
#
# Usage:
#   Call this script from the post-merge, post-rewrite, and post-checkout git hooks.
#   Format: auto-sync <git_hook_args>... -- <sync_command>...
#   Example: auto-sync git hook args -- uv sync
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
#   auto-sync.skip.checkouts-and-non-default-branch-pulls:
#     If you only want to allow syncing on your branches and the default branch, but
#     don't want to specify an `auto-sync.allow.branch-pattern` to match your
#     branches, you can enable this setting and `auto-sync.allow.all`. With those two
#     settings enabled, syncing will only happen when you pull the default branch or
#     do a non-pull rebase/merge. This works off the assumption that you would only
#     do a non-pull rebase/merge on your own branches.
#   auto-sync.allow.all (optional):
#     Set this to 'true' if syncing should be allowed on all branches.
#   auto-sync.allow.branch (optional):
#     A list of branches that should be synced.
#   auto-sync.allow.branch-pattern (optional):
#     A list of POSIX extended regular expressions[1] that match branches that should
#     be synced.
#
#   Usage:
#     Set a list option with:
#       git config --add <option_name> <option_value>
#     Set a string option with:
#       git config <option_name> <option_value>
#     Examples:
#       git config --add auto-sync.allow.branch-pattern '^my_username/.*$'
#       git config auto-sync.allow.all true
#
# [1]: https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html#index-_005b_005b

if [[ ${AUTO_SYNC_DEBUG:-} == 'true' ]]; then
  echo "AUTO_SYNC_HOOK_NAME: ${AUTO_SYNC_HOOK_NAME:?}"
  echo "Last reflog entry: $(git --no-pager reflog show --max-count 1 || true)"
  set -o xtrace
fi

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

  local last_reflog_entry
  last_reflog_entry="$(git reflog show --max-count 1)"

  local skip_checkouts_and_non_default_branch_pulls
  skip_checkouts_and_non_default_branch_pulls="$(
    safe_git_config --get 'auto-sync.skip.checkouts-and-non-default-branch-pulls'
  )"
  if [[ ${skip_checkouts_and_non_default_branch_pulls:-} == 'true' ]]; then
    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    local default_branch
    default_branch="$(get_default_branch)"
    local -r pull_regex='^.*: pull( .*)?: .+'
    if
      [[ $AUTO_SYNC_HOOK_NAME == 'post-checkout' ]] ||
        {
          [[ $last_reflog_entry =~ $pull_regex ]] &&
            [[ $current_branch != "$default_branch" ]]
        }
    then
      should_sync='false'
    fi
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

  # Disable sync in scenarios where the user probably doesn't want to run it.
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

function is_head_in_allowed_branches {
  local -a allowed_branches=()

  # The default branch is always allowed
  allowed_branches+=("$(get_default_branch)")

  local allowed_branches_string
  allowed_branches_string="$(safe_git_config --get-all 'auto-sync.allow.branch')"
  if [[ -n $allowed_branches_string ]]; then
    local -a allowed_branches_temp
    readarray -t allowed_branches_temp <<<"$allowed_branches_string"
    allowed_branches+=("${allowed_branches_temp[@]}")
  fi

  local allowed_branches_from_patterns_string
  allowed_branches_from_patterns_string="$(get_allowed_branches_from_patterns)"
  if [[ -n $allowed_branches_from_patterns_string ]]; then
    local -a allowed_branches_from_patterns
    readarray -t allowed_branches_from_patterns <<<"$allowed_branches_from_patterns_string"
    allowed_branches+=("${allowed_branches_from_patterns[@]}")
  fi

  local is_head_in_allowed_branches='false'
  for allowed_branch in "${allowed_branches[@]}"; do
    if git merge-base --is-ancestor HEAD "$allowed_branch"; then
      is_head_in_allowed_branches='true'
      break
    fi
  done
  echo "$is_head_in_allowed_branches"
}

function get_allowed_branches_from_patterns {
  branches_string="$(git for-each-ref --format='%(refname:short)' refs/heads/)"
  local -a branches
  readarray branches -t <<<"$branches_string"

  local -a allowed_branch_patterns
  local allowed_branch_patterns_string
  allowed_branch_patterns_string="$(safe_git_config --get-all 'auto-sync.allow.branch-pattern')"
  if [[ -n $allowed_branch_patterns_string ]]; then
    readarray -t allowed_branch_patterns <<<"$allowed_branch_patterns_string"
  fi

  local -a allowed_branches_from_patterns=()
  for branch in "${branches[@]}"; do
    for pattern in "${allowed_branch_patterns[@]}"; do
      if [[ $branch =~ $pattern ]]; then
        allowed_branches_from_patterns+=("$branch")
      fi
    done
  done

  if ((${#allowed_branches_from_patterns[@]} > 0)); then
    printf '%s\n' "${allowed_branches_from_patterns[@]}"
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
