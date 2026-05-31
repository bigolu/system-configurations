#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless git
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the commits specified."
#USAGE
#USAGE arg "<range>" default="head" long_help="Any commit range that `git log` accepts. Use the special value `head` to check only the `HEAD` commit. When `head` is used, the current [git worktree](https://git-scm.com/docs/git-worktree) will be checked. Otherwise, a different worktree will be created for each commit being checked, so they can be checked in parallel."
#USAGE complete "range" run=#" printf '%s\n' head "#
#USAGE
#USAGE flag "--all-files" env="ALL_FILES" help="Check all files" long_help="For faster development, jobs are only run when the files relevant to a job are changed in the commit. However, the list of relevant files for a job is not perfect so you can use this flag to consider all files changed instead of only the files changed in the commit being checked. Instead of using this flag, you can also set the environment variable `ALL_FILES` to `true`."
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
	if [[ $arg != "${usage_range:?}" ]]; then
		_lefthook_command+=("$arg")
	fi
done
if [[ ${ALL_FILES:-} == 'true' ]]; then
	_lefthook_command+=(--all-files)
fi

if [[ ${usage_range:?} == 'head' ]]; then
	# When we run on the HEAD commit, we want any fixes that get made by lefthook to be
	# applied to the current worktree. git-branchless discards any changes that
	# get made so we don't use it here.
	"${lefthook_command[@]}"
	exit
fi

hashes="$(git log "$usage_range" --pretty=%H)"
if [[ -z $hashes ]]; then
	exit
fi

git_branchless_exec_command=(
	# Use the nix environment of the commit being tested.
	#
	# Unset these environment variables so the nix environment can set new
	# values for these variables relative to the directory of the worktree.
	env --unset=PRJ_ROOT --unset=PRJ_DATA_DIR
	nix run --file . devShells.development --

	# We enable lefthook since it gets disabled below.
	env LEFTHOOK=true
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
	--exec "${git_branchless_exec_command[*]@Q}" \
	--jobs 0 \
	"${hashes//$'\n'/ | }"
