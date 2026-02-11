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

function main {
  if [[ -n ${usage_rebase:-} ]]; then
    check_commits_with_rebase
  elif [[ -n ${usage_commits:-} ]]; then
    check_commits
  else
    # Assume `--files` was given
    check_files
  fi
}

function check_commits_with_rebase {
  local start=''
  if [[ $usage_rebase == 'not-pushed' ]]; then
    start="$(git merge-base '@{push}' HEAD)"
  else
    start="$usage_rebase"
  fi

  # Save a reference to the commit we were on before the rebase started, in case
  # we want to go back.
  git update-ref refs/project/ir-backup HEAD

  local -r all_files="${usage_all_files:+ --all-files}"
  local -r jobs=${usage_jobs:+ $usage_jobs}
  # The arguments for this task should not be inherited by the one we run in `--exec`
  # or any other tasks that get run during the interactive rebase.
  unset "${!usage_@}"

  git rebase \
    --interactive \
    --exec "mise run check --commits head$all_files$jobs" \
    "$start"
}

function check_commits {
  local range=''
  if [[ $usage_commits == 'head' ]]; then
    range='HEAD^!'
  else
    range="$usage_commits"
  fi
  local hashes
  hashes="$(git log "$range" --pretty=%h)"
  if [[ -z $hashes ]]; then
    exit 0
  fi

  local -a lefthook_command
  make_lefthook_command lefthook_command

  local -a lefthook_env_variables=(LEFTHOOK_INCLUDE_COMMIT_MESSAGE=true)
  if [[ -n ${usage_all_files:-} ]]; then
    lefthook_env_variables+=(LEFTHOOK_ALL_FILES=true)
  fi

  if [[ $usage_commits == 'head' ]]; then
    # When we run this task with `--rebase`, we check each commit by running
    # this same task with `--commits head` at each commit. When we do this, we
    # want any fixes that get made by lefthook to be applied to the current
    # worktree. git-branchless discards any changes that get made so we don't
    # use it here.
    env "${lefthook_env_variables[@]}" "${lefthook_command[@]}"
  else
    local -a nix_run_env_variables=(
      # Now the nix environment we load below can set new values for these
      # variables relative to the directory of the worktree.
      --unset=PRJ_ROOT --unset=PRJ_DATA_DIR
    )
    # If we created a GC root in a development environment, it would never get
    # cleaned up.
    if [[ ${CI:-} != 'true' ]]; then
      nix_run_env_variables+=(DEVSHELL_GC_ROOT=false)
    fi

    # We enable lefthook since it gets disabled below.
    lefthook_env_variables+=(LEFTHOOK=true)

    git_branchless_command=(
      # So we can use the environment of the commit being tested
      env "${nix_run_env_variables[@]}"
      nix run --file . devShells.development --

      env "${lefthook_env_variables[@]}"
      "${lefthook_command[@]}"
    )

    # Disable lefthook so git hooks don't run when `git-branchless` checks out
    # commits.
    #
    # We can't use the cache since it isn't invalidated when the commit message
    # changes, only when the files in the commit change. This is a problem since
    # we lint commit messages.
    #
    # NOTE: The command given with `--exec` will be run with `sh -c`.
    LEFTHOOK=false git-branchless test run \
      -vv \
      --no-cache \
      --strategy worktree \
      --exec "${git_branchless_command[*]@Q}" \
      --jobs 0 \
      "${hashes//$'\n'/ | }"
  fi
}

function check_files {
  local -a lefthook_command
  make_lefthook_command lefthook_command

  local files_env_variable=''
  if [[ -n ${usage_all_files:-} ]]; then
    files_env_variable='LEFTHOOK_ALL_FILES=true'
  else
    files_env_variable='LEFTHOOK_UNCOMMITTED_FILES=true'
  fi

  env "$files_env_variable" "${lefthook_command[@]}"
}

function make_lefthook_command {
  local -n _lefthook_command=$1

  # herestring (<<<) adds a newline to the end of the string so if `usage_jobs` is
  # empty, `readarray` would set `jobs` to an array with a single empty string in
  # it instead of an empty array. To avoid this, we only use `readarray` if
  # `usage_jobs` isn't empty.
  local -a jobs
  if [[ -n ${usage_jobs:-} ]]; then
    # It's easier to split a newline-delimited string than a space-delimited one
    # since herestring (<<<) adds a newline to the end of the string.
    readarray -t jobs <<<"${usage_jobs// /$'\n'}"
  fi
  local -a job_flags=()
  for job in "${jobs[@]}"; do
    job_flags+=(--job "$job")
  done

  _lefthook_command=(lefthook run check "${job_flags[@]}")
}

main
