#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues with the code. If no flags are provided, it will behave as if `--files uncommitted` was provided. The list of jobs is in `lefthook.yaml`."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#" fish -c 'complete --do-complete "lefthook run check --jobs "' "#
#USAGE
#USAGE flag "-f --files <files>" help="Check the files specified" long_help="Check the files specified. `files` can be a revision range with the format `<start>..<end>`. This will check all the files changed in all the commits within that range (`<start>` is not included in the range). You can also provide a single revision, e.g. `HEAD`, to only check the files within the commit referenced by that revision. You can also use the format `not-in-<revision>` to check any commits that are ancestors of `HEAD`, but not ancestors of `<revision>`. This is useful for checking commits that haven't been merged to a remote e.g. `not-in-upstream`. Use the special value `uncommitted` to check any files that haven't been committed including untracked files, `not-pushed` to check the files of any commits that haven't been pushed, `head` to run on all files in the current commit (i.e. HEAD), and `all` to check all tracked/untracked files. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "files" run=#" git remote | while IFS= read -r remote; do echo "not-in-$remote"; done; printf '%s\n' uncommitted not-pushed head all "#
#USAGE
#USAGE flag "-r --rebase <start>" help="Check commits using an interactive rebase" long_help="An interactive rebase will be started from the commit referenced by the revision in `start`. An `exec` command will be added after every commit which checks the files and message for that commit. You can use the format `not-in-<revision>` to rebase any commits that are ancestors of `HEAD`, but not ancestors of `<revision>`. This is useful for checking commits that haven't been merged to a remote e.g. `not-in-upstream`. Use the special value `not-pushed` to rebase any commits that haven't been pushed. If `--files` is also used, the files specified by `--files` will be checked per commit instead of the files in the commit. If you make a mistake and want to go back to where you were before the rebase, run `git reset --hard refs/project/ir-backup`. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "start" run=#" git remote | while IFS= read -r remote; do echo "not-in-$remote"; done; printf '%s\n' not-pushed "#
#USAGE
#USAGE flag "-c --commits <commits>" help="Check the files/messages of the commits specified" long_help="Check the files and commit message of each of the commits specified. `commits` can be a revision range with the format `<start>..<end>`. This will check the files and commit message of each commit within that range (`<start>` is not included in the range). `commits` can also have the format `not-in-<revision>` to check any commits that are ancestors of `HEAD`, but not ancestors of `<revision>`. This is useful for checking commits that haven't been merged to a remote e.g. `not-in-upstream`. You can also provide a single commit, e.g. `HEAD`, if you only want to check one. Use the special value `not-pushed` to check any commits that haven't been pushed. Commits will be checked individually to ensure checks pass at each commit. If `--files` is also used, the files specified by `--files` will be checked per commit instead of the files in the commit. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "commits" run=#" git remote | while IFS= read -r remote; do echo "not-in-$remote"; done; printf '%s\n' not-pushed head "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

jobs="${usage_jobs:+${usage_jobs// /,}}"

if [[ -n ${usage_rebase:-} ]]; then
  # Documentation for git range specifiers[1].
  #
  # [1]: https://git-scm.com/docs/git-rev-parse#_specifying_ranges
  case "$usage_rebase" in
    'not-pushed')
      start="$(git merge-base '@{push}' HEAD)"
      ;;
    'not-in-'*)
      remote="${usage_rebase#not-in-}"
      if ! git rev-parse --verify --quiet "$remote" >/dev/null; then
        echo "error: Remote '$remote' does not exist" >&2
        exit 1
      fi
      start="$(git merge-base "$remote" 'HEAD')"
      ;;
    *)
      start="$usage_rebase^"
      ;;
  esac

  # Save a reference to the commit we were on before the rebase started, in case we
  # want to go back.
  git update-ref refs/project/ir-backup HEAD

  if [[ -n ${jobs:-} ]]; then
    readarray -t job_array <<<"${jobs//,/$'\n'}"
    printf -v escaped_job_array ' %q' "${job_array[@]}"
  else
    escaped_job_array=''
  fi

  escaped_files="${usage_files:+ --files ${usage_files@Q}}"

  # The arguments for this task should not be inherited by the one we run in `--exec`
  # or any other tasks that get run during the interactive rebase.
  unset "${!usage_@}"

  git rebase \
    --interactive \
    --exec "mise run check --commits head$escaped_files$escaped_job_array" \
    "$start"
elif [[ -n ${usage_commits:-} ]]; then
  # Documentation for git range specifiers[1].
  #
  # [1]: https://git-scm.com/docs/git-rev-parse#_specifying_ranges
  case "$usage_commits" in
    'not-pushed')
      range="$(git merge-base '@{push}' HEAD).."
      ;;
    'not-in-'*)
      remote="${usage_commits#not-in-}"
      if ! git rev-parse --verify --quiet "$remote" >/dev/null; then
        echo "error: Remote '$remote' does not exist" >&2
        exit 1
      fi
      range="$(git merge-base "$remote" 'HEAD').."
      ;;
    'head')
      range='HEAD^!'
      ;;
    *'..'*)
      range="$usage_commits"
      ;;
    *)
      range="$usage_commits^!"
      ;;
  esac

  hashes="$(git log "$range" --pretty=%h)"
  if [[ -z $hashes ]]; then
    exit 0
  fi

  files="${usage_files:-head}"
  # Disable lefthook so git hooks don't run when `git-branchless` checks out commits.
  #
  # We can't use the cache since the cache doesn't invalidate when the commit message
  # changes, only when the files in the commit change.
  LEFTHOOK=0 git-branchless test run \
    -vv \
    --no-cache \
    --strategy worktree \
    --exec "LEFTHOOK=1 LEFTHOOK_INCLUDE_COMMIT_MESSAGE=true LEFTHOOK_FILES=${files@Q} RUN_FIX_ACTIONS='diff,stash,fail' lefthook run check --jobs ${jobs@Q}" \
    "${hashes//$'\n'/ | }"
else
  LEFTHOOK_FILES="${usage_files:-uncommitted}" lefthook run check --jobs "$jobs"
fi
