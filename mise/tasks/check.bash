#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues with the code. If no flags are provided, it will behave as if `--files uncommitted` was provided. The list of jobs is in `lefthook.yaml`."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#"""
#USAGE   fish -c 'complete --do-complete "lefthook run check --jobs "'
#USAGE """#
#USAGE
#USAGE flag "-f --files <file_commit_range>" help="Check the files of the given commits" long_help="Check the files of the commits in the given commit range. `file_commit_range` has the form `<from>..<to>` e.g. `17f0a477..HEAD`. You can also provide a single commit, e.g. `HEAD`, if you only want to check one. Use the special value `uncommitted` to check any files that having been committed including untracked files, `unpushed` to check the files of any commits that haven't been pushed, and `all` to check all tracked/untracked files."
#USAGE complete "file_commit_range" run=#"""
#USAGE   printf '%s\n' uncommitted unpushed all
#USAGE """#
#USAGE
#USAGE flag "-c --commits <commit_range>" help="Check the files/messages of the given commits" long_help="Check the files and commit message of each commit in the provided commit range. A commit range has the form `<from>..<to>` e.g. `17f0a477..HEAD`. You can also provide a single commit, e.g. `HEAD`, if you only want to check one. Use the special value `unpushed` to check any commits that haven't been pushed. Commits will be checked individually to ensure all checks pass at each commit."
#USAGE complete "commit_range" run=#"""
#USAGE   printf '%s\n' unpushed HEAD
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Documentation for git range specifiers[1].
#
# [1]: https://git-scm.com/docs/git-rev-parse#_specifying_ranges

commit_range="${usage_commit_range:-}"
if [[ -n $commit_range ]]; then
  start=
  end=
  hashes_string="$(git log "$start" "$end" --pretty=%h)"
  readarray -t hashes <<<"$hashes_string"
  for hash in "${hashes[@]}"; do
    # TODO: worktree or stash
    if [[ -n $usage_jobs ]]; then
      # It's easier to split a newline-delimited string than a space-delimited one
      # since herestring (<<<) adds a newline to the end of the string.
      readarray -t jobs <<<"${usage_jobs// /$'\n'}"
    else
      jobs=()
    fi
    RUN_FIX_ACTIONS='diff,fail' \
      mise run check --files "${usage_file_commit_range:-$hash}" "${jobs[@]}"
  done
fi

LEFTHOOK_FILE_COMMIT_RANGE="${usage_file_commit_range:-}" \
  lefthook run check --jobs "${usage_jobs:+${usage_jobs// /,}}"
