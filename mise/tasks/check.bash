# The first line in the file can't be a `nix-shell` directive because mise would misinterpret it as a shebang.
#! nix-shell -i bash
#! nix-shell --packages bash git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the commits specified."
#USAGE
#USAGE arg "<start>" default="HEAD" long_help="The commit to start checking from. Commits from `start` to the current commit (`HEAD`) will be checked. By default only `HEAD` is checked."
#USAGE
#USAGE flag "--all-files" help="Check all files" long_help="For faster development, we decide whether a job runs, and which files it runs on, based on the files changed by the commit being checked. This way, you can skip checks that aren't related to the files you changed. However, sometimes a job is skipped when it shouldn't be so you can use this flag to consider all files changed instead of only the files changed in the commit being checked."
#USAGE
#USAGE flag "--job <job>" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `lefthook.yaml` under the `check` hook."
#USAGE complete "job" run=#" fish -c 'complete --do-complete "lefthook run check --job "' "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

lefthook_command=(lefthook run check)
for arg in "$@"; do
	if [[ $arg != "${usage_start:?}" ]]; then
		lefthook_command+=("$arg")
	fi
done

start="$usage_start"
# mise sets variables starting with `usage_` or `MISE_` when a task is run.
# Tasks run within the checks shouldn't inherit the variables from this task.
#
# Unset the variables starting with  `PRJ_` so the nix environment can set new
# values for them relative to the directory of the worktree.
unset "${!usage_@}" "${!MISE_@}" "${!PRJ_@}"

if [[ $start == 'HEAD' ]]; then
	# Normally, we use git-branchless to run the checks since it can check multiple
	# commits in parallel. However, git-branchless discards any changes that get
	# made while running checks, which would discard any fixes that are made. To
	# work around this, we don't use git-branchless when we're only running on the
	# HEAD commit.
	"${lefthook_command[@]}"
	exit
fi

git_branchless_exec_command=(
	# Load the nix environment since we'll be in a new worktree and may need to do
	# some setup.
	nix run --file nix/flake-compat.nix outputsForCurrentSystem.devShells.dev --
	# We enable lefthook since it gets disabled below.
	env LEFTHOOK=true "${lefthook_command[@]}"
)
# Disable lefthook so git hooks don't run when `git-branchless` runs git commands.
#
# We can't use the cache since it isn't invalidated when the commit message
# changes, only when the files in the commit change. This is a problem since
# we lint commit messages.
LEFTHOOK=false git-branchless test run \
	--verbose --verbose \
	--no-cache \
	--jobs 0 \
	--exec "${git_branchless_exec_command[*]@Q}" \
	"${start}:HEAD"
