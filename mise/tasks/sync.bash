#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description="Sync your environment with the code"
#USAGE long_about "Run jobs to sync your environment with the code. For example, running database migrations whenever the schema changes. You shouldn't have to run this manually since git hooks are provided to automatically run this after rebases, merges, and checkouts. The list of jobs is in `lefthook.yaml`."
#USAGE
#USAGE arg "[jobs]" var=#true help="Jobs to run. If none are passed then all of them will be run"
#USAGE complete "jobs" run=#" fish -c 'complete --do-complete "lefthook run sync --job "' "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# herestring (<<<) adds a newline to the end of the string so if `usage_jobs` is
# empty, `readarray` would set `jobs` to an array with a single empty string in
# it instead of an empty array. To avoid this, we only use `readarray` if
# `usage_jobs` isn't empty.
if [[ -n ${usage_jobs:-} ]]; then
  # It's easier to split a newline-delimited string than a space-delimited one
  # since herestring (<<<) adds a newline to the end of the string.
  readarray -t jobs <<<"${usage_jobs// /$'\n'}"
else
  jobs=()
fi

job_flags=()
for job in "${jobs[@]}"; do
  job_flags+=(--job "$job")
done

lefthook run sync "${job_flags[@]}"
