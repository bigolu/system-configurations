#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues with the code. The list of jobs is in `lefthook.yaml`. If no flags are passed, it will behave as if `--files` was passed."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#" fish -c 'complete --do-complete "lefthook run check --job "' "#
#USAGE
#USAGE flag "-f --files" help="Check files with uncommitted changes" long_help="Check any files that have uncommitted changes."
#USAGE
#USAGE flag "-r --rebase <start>" help="Check commits using an interactive rebase" long_help="An interactive rebase will be started from the commit referenced by the revision in `start`. An `exec` command will be added after every commit which checks the files and message for that commit. Use the special value `not-pushed` to rebase any commits that haven't been pushed. If you make a mistake and want to go back to where you were before the rebase, run `git reset --hard refs/project/ir-backup`. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "start" run=#" printf '%s\n' not-pushed "#
#USAGE
#USAGE flag "-c --commits <commits>" help="Check the files/messages of the commits specified" long_help="Check the files and commit message of each of the commits specified. `commits` can be any revision, or revision range, that `git log` accepts. Use the special value `head` to check the files in the `HEAD` commit. Commits will be checked individually to ensure checks pass at each commit. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions)."
#USAGE complete "commits" run=#" printf '%s\n' head "#
#USAGE
#USAGE flag "-a --all-files" help="Check all files" long_help="This is can be used with `--rebase` or `--commits` to check all files instead of only the files in the commits being checked/rebased. It can also be used with `--files` to check all files instead of only the ones with uncommitted changes."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ -n ${usage_rebase:-} ]]; then
  if [[ $usage_rebase == 'not-pushed' ]]; then
    start="$(git merge-base '@{push}' HEAD)"
  else
    start="$usage_rebase"
  fi

  # Save a reference to the commit we were on before the rebase started, in case
  # we want to go back.
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

  exit 0
fi

# herestring (<<<) adds a newline to the end of the string so if `usage_jobs` is
# empty, `readarray` would set `jobs` to an array with a single empty string in
# it instead of an empty array. To avoid this, we only use `readarray` if
# `usage_jobs` isn't empty.
if [[ -n ${usage_jobs:-} ]]; then
  # It's easier to split a newline-delimited string than a space-delimited one
  # since herestring (<<<) adds a newline to the end of the string.
  readarray -t jobs <<<"${usage_jobs// /$'\n'}"
else
  jobs=()
fi
job_flags=()
for job in "${jobs[@]}"; do
  job_flags+=(--job "$job")
done
lefthook_command=(env LEFTHOOK_ALL_FILES="${usage_all_files:-}" lefthook run check "${job_flags[@]}")

if [[ -n ${usage_commits:-} ]]; then
  if [[ $usage_commits == 'head' ]]; then
    range='HEAD^!'
  else
    range="$usage_commits"
  fi

  hashes="$(git log "$range" --pretty=%h)"
  if [[ -z $hashes ]]; then
    exit 0
  fi

  lefthook_command=(env LEFTHOOK_INCLUDE_COMMIT_MESSAGE=true "${lefthook_command[@]}")

  readarray -t hashes_array <<<"$hashes"
  if ((${#hashes_array[@]} == 1)); then
    # We don't use git-branchless to ensure that any fixes made by lefthook get
    # applied to the current worktree. git-branchless has an option to use to
    # the current worktree, but it requires that the worktree be clean and we
    # don't want to have that restriction.
    "${lefthook_command[@]}"
  else
    # We enable lefthook since it gets disabled below.
    #
    # We use `nix run ...` to ensure that we use the development environment at
    # the commit being tested.
    #
    # We unset `PRJ_ROOT` so nix doesn't reuse the current value of `PRJ_ROOT`
    # and instead uses `PWD` which will be the path to the worktree.
    lefthook_command=(env --unset=PRJ_ROOT nix run --file . devShells.development -- env LEFTHOOK=1 "${lefthook_command[@]}")

    # Disable lefthook so git hooks don't run when `git-branchless` checks out
    # commits.
    #
    # We can't use the cache since the cache doesn't invalidate when the commit
    # message changes, only when the files in the commit change, and we lint
    # commit messages.
    #
    # NOTE: The command given with `--exec` will be run with `sh -c`.
    LEFTHOOK=0 git-branchless test run \
      -vv \
      --no-cache \
      --strategy worktree \
      --exec "${lefthook_command[*]@Q}" \
      --interactive \
      "${hashes//$'\n'/ | }"
  fi

  exit 0
fi

# Assume `--files` was given
LEFTHOOK_UNCOMMITTED_FILES='true' "${lefthook_command[@]}"
