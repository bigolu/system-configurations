#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues with the code. If no flags are provided, it will behave as if `--all-files` was provided. The list of jobs is in `lefthook.yaml`."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#" fish -c 'complete --do-complete "lefthook run check --jobs "' "#
#USAGE
#USAGE flag "-a --all-files" help="Check all files"
#USAGE
#USAGE flag "-r --rebase <start>" help="Check commits using an interactive rebase" long_help="An interactive rebase will be started from the commit referenced by the revision in `start`. An `exec` command will be added after every commit which checks the files and message for that commit. Use the special value `not-pushed` to rebase any commits that haven't been pushed. If `--all-files` is also used, all files will be checked per commit instead of only the files in the commit. If you make a mistake and want to go back to where you were before the rebase, run `git reset --hard refs/project/ir-backup`. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "start" run=#" printf '%s\n' not-pushed "#
#USAGE
#USAGE flag "-c --commits <commits>" help="Check the files/messages of the commits specified" long_help="Check the files and commit message of each of the commits specified. `commits` can be any revision, or revision range, that `git log` accepts. Use the special value `head` to check the files in the `HEAD` commit. Commits will be checked individually to ensure checks pass at each commit. If `--all-files` is also used, all files will be checked per commit instead of only the files in the commit. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "commits" run=#" printf '%s\n' head "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

jobs="${usage_jobs:+${usage_jobs// /,}}"

if [[ -n ${usage_rebase:-} ]]; then
  case "$usage_rebase" in
    'not-pushed')
      start="$(git merge-base '@{push}' HEAD)"
      ;;
    *)
      start="$usage_rebase"
      ;;
  esac

  # Save a reference to the commit we were on before the rebase started, in case we
  # want to go back.
  git update-ref refs/project/ir-backup HEAD

  all_files="${usage_all_files:+ --all-files}"
  jobs=${usage_jobs:+ $usage_jobs}
  # The arguments for this task should not be inherited by the one we run in `--exec`
  # or any other tasks that get run during the interactive rebase.
  unset "${!usage_@}"

  git rebase \
    --interactive \
    --exec "mise run check --commits head$all_files$jobs" \
    "$start"
elif [[ -n ${usage_commits:-} ]]; then
  case "$usage_commits" in
    'head')
      range='HEAD^!'
      ;;
    *)
      range="$usage_commits"
      ;;
  esac

  hashes="$(git log "$range" --pretty=%h)"
  if [[ -z $hashes ]]; then
    exit 0
  fi

  command="LEFTHOOK=1 LEFTHOOK_INCLUDE_COMMIT_MESSAGE=true LEFTHOOK_ALL_FILES=${usage_all_files:-} lefthook run check --jobs ${jobs@Q}"
  readarray -t hashes_array <<<"$hashes"
  if ((${#hashes_array[@]} == 1)); then
    # This way fixes will be retained in the main worktree
    eval "$command"
  else
    # Disable lefthook so git hooks don't run when `git-branchless` checks out
    # commits.
    #
    # We can't use the cache since the cache doesn't invalidate when the commit
    # message changes, only when the files in the commit change.
    LEFTHOOK=0 git-branchless test run \
      -vv \
      --no-cache \
      --strategy worktree \
      --exec "$command" \
      "${hashes//$'\n'/ | }"
  fi
else
  LEFTHOOK_ALL_FILES='true' lefthook run check --jobs "$jobs"
fi
