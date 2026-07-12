#nix --interpreter bash --packages bash
#MISE description="Sync your environment with the code"
#USAGE long_about "Run jobs to sync your environment with the code. For example, running database migrations whenever the schema changes."
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `sync` hook."
#USAGE flag "--ask" help="Show diff and confirm before syncing" long_help="Show a diff of the current state and the new state, and ask for confirmation, before syncing. This is only supported by the `system` job."
#USAGE flag "--verbose -v" help="Show the sync jobs' logs" long_help="Show the logs for the sync job. This is only supported by the `system` job."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

command=(hk run sync)

for arg in "$@"; do
	if [[ $arg != '--ask' && $arg != '--verbose' && $arg != '-v' ]]; then
		command+=(--step "$arg")
	fi
done

if [[ -n ${GIT_AUTO_SYNC_LAST_COMMIT:-} ]]; then
	command+=(--from-ref "$GIT_AUTO_SYNC_LAST_COMMIT" --to-ref HEAD)
else
	command+=(--all)
fi

"${command[@]}"
