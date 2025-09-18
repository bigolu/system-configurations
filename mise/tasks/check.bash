#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues with the code. If no flags are provided, it will behave as if `--files uncommitted` was provided. The list of jobs is in `lefthook.yaml`."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#"""
#USAGE   fish -c 'complete --do-complete "lefthook run check --jobs "'
#USAGE """#
#USAGE
#USAGE flag "-f --files <files>" help="Check the files specified" long_help="Check the files specified. `files` can be a commit range with the format `<start>..<end>` e.g. `17f0a477..HEAD`. This will check all the files changed in all the commits within that range (the range excludes the start commit). You can also provide a single commit, e.g. `HEAD`, if you only want to check the files within one. Use the special value `uncommitted` to check any files that haven't been committed including untracked files, `unpushed` to check the files of any commits that haven't been pushed, `not-in-upstream` to check the files of any commits that are not in `upstream/HEAD` (there must be a remote named `upstream` for this to work), and `all` to check all tracked/untracked files."
#USAGE complete "files" run=#"""
#USAGE   printf '%s\n' uncommitted unpushed not-in-upstream all
#USAGE """#
#USAGE
#USAGE flag "-r --rebase <start>" help="Check commits using an interactive rebase" long_help="An interactive rebase will be started from the commit `start`. An `exec` command will be added after every commit which checks the files and message for that commit. Use the special value `unpushed` to rebase any commits that haven't been pushed or `not-in-upstream` to rebase any commits that are not in `upstream/HEAD` (requires a remote named `upstream`)."
#USAGE complete "start" run=#"""
#USAGE   printf '%s\n' unpushed not-in-upstream
#USAGE """#
#USAGE
#USAGE flag "-c --commits <commits>" help="Check the files/messages of the commits specified" long_help="Check the files and commit message of each of the commits specified. `commits` can be a commit range with the format `<start>..<end>` e.g. `17f0a477..HEAD`. This will check the files and commit message of each commit within that range. You can also provide a single commit, e.g. `HEAD`, if you only want to check one. Use the special value `unpushed` to check any commits that haven't been pushed or `not-in-upstream` to check any commits that are not in `upstream/HEAD` (there must be a remote named `upstream` for this to work). Commits will be checked individually to ensure checks pass at each commit. The working tree must be clean to run this, meaning there are no uncommitted changes."
#USAGE complete "commits" run=#"""
#USAGE   printf '%s\n' unpushed not-in-upstream HEAD
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ -z ${usage_rebase:-} && -z ${usage_commits:-} && -z ${usage_files:-} ]]; then
  usage_files='uncommitted'
fi

if [[ -n ${usage_rebase:-} ]]; then
  # Documentation for git range specifiers[1].
  #
  # [1]: https://git-scm.com/docs/git-rev-parse#_specifying_ranges
  case "$usage_rebase" in
    'unpushed')
      start="$(git merge-base '@{push}' HEAD)"
      ;;
    'not-in-upstream')
      upstream='upstream/HEAD'
      if ! git rev-parse --verify --quiet "$upstream" >/dev/null; then
        echo "Error: ref '$upstream' does not exist" >&2
        exit 1
      fi
      start="$(git merge-base "$upstream" 'HEAD')"
      ;;
    *)
      start="$usage_rebase^"
      ;;
  esac

  git rebase \
    --interactive \
    --exec "env LEFTHOOK_COMMIT=HEAD LEFTHOOK_FILES=$(printf '%q' "${usage_files:-}") lefthook run check --jobs $(printf '%q' "${usage_jobs:+${usage_jobs// /,}}")" \
    "$start"
elif [[ -n ${usage_commits:-} ]]; then
  # Documentation for git range specifiers[1].
  #
  # [1]: https://git-scm.com/docs/git-rev-parse#_specifying_ranges
  case "$usage_commits" in
    'unpushed')
      start="^$(git merge-base '@{push}' HEAD)"
      end='HEAD'
      ;;
    'not-in-upstream')
      upstream='upstream/HEAD'
      if ! git rev-parse --verify --quiet "$upstream" >/dev/null; then
        echo "Error: ref '$upstream' does not exist" >&2
        exit 1
      fi
      start="^$(git merge-base "$upstream" 'HEAD')"
      end='HEAD'
      ;;
    *'..'*)
      start="${usage_commits%..*}^!"
      end="${usage_commits#*..}"
      ;;
    *)
      start="$usage_commits^!"
      end="$start"
      ;;
  esac

  hashes="$(git log "$start" "$end" --pretty=%h)"
  if [[ -z $hashes ]]; then
    exit 0
  fi

  # Disable lefthook temporarily so git hooks don't run.
  #
  # We can't use the cache since the cache doesn't invalidate when the commit message
  # changes, only when the files in the commit change.
  LEFTHOOK=0 git-branchless test run -vv --no-cache --exec "
    # We use env from within the direnv environment so we can override the variables
    # set by direnv.
    direnv exec . \
      env \
      LEFTHOOK=1 \
      LEFTHOOK_COMMIT=\"\$BRANCHLESS_TEST_COMMIT\" \
      LEFTHOOK_FILES=$(printf '%q' "${usage_files:-}") \
      lefthook run check --jobs $(printf '%q' "${usage_jobs:+${usage_jobs// /,}}")
  " "${hashes//$'\n'/ | }"
else
  LEFTHOOK_FILES="${usage_files:-}" \
    lefthook run check --jobs "${usage_jobs:+${usage_jobs// /,}}"
fi
