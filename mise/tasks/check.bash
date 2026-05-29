#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter git-branchless
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the commits specified."
#USAGE
#USAGE arg "<start>" default="head" long_help="The commit to start checking from. Use the special value `head` to check only the `HEAD` commit. Use `not-pushed` to start from the first commit that hasn't been pushed. See [git's documentation for specifying a revision](https://git-scm.com/docs/git-rev-parse#_specifying_revisions). When `head` is used, the current [git worktree](https://git-scm.com/docs/git-worktree) will be checked. Otherwise, a different worktree will be created for each commit being checked, so they can be checked in parallel."
#USAGE complete "start" run=#" printf '%s\n' not-pushed head "#
#USAGE
#USAGE flag "-a --all-files" help="Check all files" long_help="Check all files instead of only the files changed in the commit being checked."
#USAGE
#USAGE flag "-j --job <job>" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `lefthook.yaml` under the `check` hook."
#USAGE complete "job" run=#" fish -c 'complete --do-complete "lefthook run check --job "' "#
#USAGE
#USAGE flag "-r --rebase" help="Use interactive rebase" long_help="Check commits using an interactive rebase. An `exec` command will be added after every commit which checks the files and message for that commit. If you make a mistake and want to go back to where you were before the rebase, run `git reset --hard refs/project/ir-backup`."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
	if [[ -n ${usage_rebase:-} ]]; then
		check_commits_with_rebase
	else
		check_commits
	fi
}

function check_commits_with_rebase {
	local start=''
	if [[ ${usage_start:?} == 'not-pushed' ]]; then
		start="$(git merge-base '@{push}' HEAD)"
	else
		start="${usage_start}^"
	fi

	# Save a reference to the commit we were on before the rebase started, in case
	# we want to go back.
	git update-ref refs/project/ir-backup HEAD

	local -r all_files="${usage_all_files:+ --all-files}"

	local -a job_flags=()
	make_job_flags job_flags
	local job_flags_string
	if ((${#job_flags[@]} > 0)); then
		job_flags_string=" ${job_flags[*]}"
	else
		job_flags_string=''
	fi

	# The arguments for this task should not be inherited by the one we run in `--exec`
	# or any other tasks that get run during the interactive rebase.
	unset "${!usage_@}"

	git rebase \
		--interactive \
		--exec "mise run check head$all_files$job_flags_string" \
		"$start"
}

function check_commits {
	local -a lefthook_command
	make_lefthook_command lefthook_command

	local -a lefthook_env_variables=(LEFTHOOK_INCLUDE_COMMIT_MESSAGE=true)
	if [[ -n ${usage_all_files:-} ]]; then
		lefthook_env_variables+=(LEFTHOOK_FILES=all)
	else
		lefthook_env_variables+=(LEFTHOOK_FILES=head)
	fi

	if [[ ${usage_start:?} == 'head' ]]; then
		# When we run this task with the subcommand `rebase`, we check each commit
		# by running this same task with the arguments `commits head` at each
		# commit. When we do this, we want any fixes that get made by lefthook to be
		# applied to the current worktree. git-branchless discards any changes that
		# get made so we don't use it here.
		env "${lefthook_env_variables[@]}" "${lefthook_command[@]}"
		return
	fi

	local hashes
	hashes="$(git log "${usage_start}^..HEAD" --pretty=%h)"
	if [[ -z $hashes ]]; then
		return 0
	fi

	# We enable lefthook since it gets disabled below.
	lefthook_env_variables+=(LEFTHOOK=true)

	git_branchless_exec_command=(
		# Use the nix environment of the commit being tested.
		#
		# Unset these environment variables so the nix environment can set new
		# values for these variables relative to the directory of the worktree.
		env --unset=PRJ_ROOT --unset=PRJ_DATA_DIR
		nix run --file . devShells.development --

		env "${lefthook_env_variables[@]}"
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
}

function make_lefthook_command {
	local -n _lefthook_command=$1

	local -a job_flags=()
	make_job_flags job_flags

	_lefthook_command=(lefthook run check "${job_flags[@]}")
}

function make_job_flags {
	local -n _job_flags=$1

	# herestring (<<<) adds a newline to the end of the string so if `usage_job` is
	# empty, `readarray` would set `jobs` to an array with a single empty string in
	# it instead of an empty array. To avoid this, we only use `readarray` if
	# `usage_job` isn't empty.
	local -a jobs
	if [[ -n ${usage_job:-} ]]; then
		# It's easier to split a newline-delimited string than a space-delimited one
		# since herestring (<<<) adds a newline to the end of the string.
		readarray -t jobs <<<"${usage_job// /$'\n'}"
	fi
	for job in "${jobs[@]}"; do
		_job_flags+=(--job "$job")
	done
}

main
