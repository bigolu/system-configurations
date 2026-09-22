#nix --interpreter nu --packages nushell
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the current commit (HEAD)."
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `check` hook."

let job_args = if usage_job in $env {
	$env.usage_job | split row ' '
} else {
	[]
}
	| each {|job| [ --step $job ]}
	| flatten

hk run check --fix --all ...$job_args
