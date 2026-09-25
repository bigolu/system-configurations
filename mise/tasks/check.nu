#nix --interpreter nu --packages nushell
#MISE description="Run jobs to find/fix issues"
#USAGE long_about "Run jobs to find/fix issues in the current commit (HEAD)."
#USAGE complete "job" run=#" nu --commands 'generate {|steps| let pairs = ($steps | transpose name value); let out = $pairs | where $it.value._type == step | get name; let next = $pairs | where $it.value._type == group | each { $in.value.steps }; if ($out | is-not-empty) { { out: $out } } else { { } } | if ($next | is-not-empty) { merge { next: $next } } else { $in }; } (pkl eval --format json hk.pkl | from json | get hooks.check.steps) | flatten | str join (char newline)' "#
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `check` hook."

let job_args = if usage_job in $env {
  $env.usage_job | split row ' '
} else {
  []
}
| each { prepend '--step' }
| flatten

hk run check --fix --all ...$job_args
