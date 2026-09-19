#nix --interpreter nu --packages nushell
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the current commit (HEAD)."
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `check` hook."

let job_args = $env.usage_job?
	| default ""
	| if ($in | is-not-empty) { split row ' ' } else { [] }
	| each {|job| [ --step $job ]}
	| flatten

# Why fixes should run before checks:
#   - A fix could produce code that would fail a check
#   - A fix could fix an issue that would have been found by a check
let fix_exit_code = try {
		hk run fix --all ...$job_args
		$env.LAST_EXIT_CODE
	} catch {
		$env.LAST_EXIT_CODE
	}

# If the fix command fails due to the `fail_on_fix` option, we still want to run
# checks. To do so, we exit with the fix command's exit code _after_ running the
# checks.
hk run check --all ...$job_args
exit $fix_exit_code
