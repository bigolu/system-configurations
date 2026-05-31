#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless git
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the commits specified."
#USAGE
#USAGE arg "<range>" default="HEAD^!" long_help="Any commit range that `git log` accepts. By default only the head commit is checked."
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

hashes="$(git log "$usage_range" --pretty=%H)"
if [[ -z $hashes ]]; then
	exit
fi
hashes="${hashes//$'\n'/ | }"

if [[ ${CI:-} != 'true' ]]; then
	# Disable lefthook so git hooks don't run when `git-branchless` runs git commands.
	#
	# TODO: This doesn't work if `--strategy worktree` is used though I'm not sure why.
	LEFTHOOK=false git-branchless test fix \
		--verbose --verbose \
		--force-rewrite \
		--exec 'LEFTHOOK=true lefthook run check --job fix' \
		"$hashes"
fi

git_branchless_exec_command=(
	# Use the nix environment of the commit being tested. This is necessary since we'll be in a new worktree.
	#
	# Unset these environment variables so the nix environment can set new
	# values for these variables relative to the directory of the worktree.
	# env --unset=PRJ_ROOT --unset=PRJ_DATA_DIR
	# nix run --file . devShells.development --

	# We enable lefthook since it gets disabled below.
	env LEFTHOOK=true
	"${lefthook_command[@]}"
)
# Disable lefthook so git hooks don't run when `git-branchless` runs git commands.
#
# We can't use the cache since it isn't invalidated when the commit message
# changes, only when the files in the commit change. This is a problem since
# we lint commit messages.
LEFTHOOK=false git-branchless test run \
	--verbose --verbose \
	--no-cache \
	--strategy worktree \
	--exec "${git_branchless_exec_command[*]@Q}" \
	--jobs 0 \
	"$hashes"
