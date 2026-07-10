#nix --interpreter bash --packages bash
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the current commit (HEAD)."
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `check` hook."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

fix_command=(hk run fix --all)
check_command=(hk run check --all)

for arg in "$@"; do
	fix_command+=(--step "$arg")
	check_command+=(--step "$arg")
done

set +o errexit
# Why fixes should run before checks:
#   - A fix could produce code that would fail a check
#   - A fix could fix an issue that would have been found by a check
"${fix_command[@]}"
fix_exit_code=$?
set -o errexit

# If the fix command fails due to the `fail_on_fix` option, we still want to run
# checks. To do so, we exit with the fix command's exit code _after_ running the
# checks.
"${check_command[@]}" && exit "$fix_exit_code"
