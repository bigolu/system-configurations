#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues with the code. If no flags are provided, it will behave as if `--files unpushed` was provided. The list of jobs is in `lefthook.yaml`."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#"""
#USAGE   fish -c 'complete --do-complete "lefthook run check --jobs "'
#USAGE """#
#USAGE
#USAGE flag "-f --files <files>" help="Check the files specified" long_help="Check the files specified. `files` can be a commit range with the format `<start>..<end>` e.g. `17f0a477..HEAD`. This will check all the files changed in all the commits within that range (the range excludes the start commit). You can also provide a single commit, e.g. `HEAD`, if you only want to check the files within one. Use the special value `uncommitted` to check any files that haven't been committed including untracked files, `unpushed` to check the files of any commits that haven't been pushed, and `all` to check all tracked/untracked files."
#USAGE complete "files" run=#"""
#USAGE   printf '%s\n' uncommitted unpushed all
#USAGE """#
#USAGE
#USAGE flag "-c --commits <commits>" help="Check the files/messages of the commits specified" long_help="Check the files and commit message of each of the commits specified. `commits` can be a commit range with the format `<start>..<end>` e.g. `17f0a477..HEAD`. This will check the files and commit message of each commit within that range (the range excludes the start commit). You can also provide a single commit, e.g. `HEAD`, if you only want to check one. Use the special value `unpushed` to check any commits that haven't been pushed. Commits will be checked individually to ensure checks pass at each commit."
#USAGE complete "commits" run=#"""
#USAGE   printf '%s\n' unpushed HEAD
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ -z ${usage_commits:-} && -z ${usage_files:-} ]]; then
  usage_files='unpushed'
fi

if [[ -n ${usage_commits:-} ]]; then
  # Documentation for git range specifiers[1].
  #
  # [1]: https://git-scm.com/docs/git-rev-parse#_specifying_ranges
  case "$usage_commits" in
    'unpushed')
      start='^@{push}'
      end='HEAD'
      ;;
    *'..'*)
      start="${usage_commits%..*}"
      end="${usage_commits#*..}"
      # In case start is ahead of end
      start="$(git merge-base "$start" "$end")"
      ;;
    *)
      start="$usage_commits^!"
      end="$start"
      ;;
  esac

  hashes="$(git log "$start" "$end" --pretty=%h)"

  # shellcheck disable=2016
  LEFTHOOK=0 git-branchless test run -vv --strategy worktree --no-cache --exec "
    ln -sf $(printf '%q' "${PRJ_ROOT:?}/.envrc") .envrc
    LEFTHOOK=1 \
      LEFTHOOK_COMMIT=\"\$BRANCHLESS_TEST_COMMIT\" \
      LEFTHOOK_FILES=$(printf '%q' "${usage_files:-}") \
      RUN_FIX_ACTIONS='diff,stash,fail' \
      direnv exec . \
      lefthook run check --jobs $(printf '%q' "${usage_jobs:+${usage_jobs// /,}}")
  " "${hashes//$'\n'/ | }"
else
  LEFTHOOK_FILES="${usage_files:-}" \
    lefthook run check --jobs "${usage_jobs:+${usage_jobs// /,}}"
fi
