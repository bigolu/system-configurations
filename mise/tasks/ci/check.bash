#nix --interpreter bash
#nix --packages bash git-branchless
#MISE hide=true
#MISE description="Run all checks"
#USAGE long_about "Run all checks on the commits specified."
#USAGE
#USAGE arg "<start>" default="HEAD" long_help="The commit to start checking from. Commits from `start` to the current commit (`HEAD`) will be checked. By default only `HEAD` is checked."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

start="${usage_start:?}"
# mise sets variables starting with `usage_` or `MISE_` when a task is run.
# Tasks run within the checks shouldn't inherit the variables from this task.
#
# Unset the variables starting with  `PRJ_` so the nix environment can set new
# values for them relative to the directory of the worktree.
unset "${!usage_@}" "${!MISE_@}" "${!PRJ_@}"

git_branchless_exec_command=(
	# Load the nix environment since we'll be in a new worktree and may need to do
	# some setup.
	nix run --file nix/flake-compat.nix outputsForCurrentSystem.devShells.dev --
	# We enable lefthook since it gets disabled below.
	env LEFTHOOK=true lefthook run check --all-files
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
