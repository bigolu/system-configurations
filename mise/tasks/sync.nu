#nix --interpreter nu --packages nushell
#MISE description="Sync your environment with the code"
#USAGE long_about "Run jobs to sync your environment with the code. For example, running database migrations whenever the schema changes."
#USAGE complete "job" run=#" nu --commands 'generate {|steps| let pairs = ($steps | transpose name value); let out = $pairs | where $it.value._type == step | get name; let next = $pairs | where $it.value._type == group | each { $in.value.steps }; if ($out | is-not-empty) { { out: $out } } else { { } } | if ($next | is-not-empty) { merge { next: $next } } else { $in }; } (pkl eval --format json hk.pkl | from json | get hooks.sync.steps) | flatten | str join (char newline)' "#
#USAGE arg "[job]" var=#true help="Job to run" long_help="Job to run. If none are passed then all of them will be run. The list of jobs is in `hk.pkl` under the `sync` hook."
#USAGE flag "--ask" help="Show diff and confirm before syncing" long_help="Show a diff of the current state and the new state, and ask for confirmation, before syncing. This is only supported by the `system` job."

let job_args = if usage_job in $env {
  $env.usage_job | split row ' '
} else {
  []
}
| each {|job| [ --step $job ]}
| flatten

let file_args = if ($env.GIT_AUTO_SYNC_LAST_COMMIT? | is-not-empty) {
  [--from-ref $env.GIT_AUTO_SYNC_LAST_COMMIT --to-ref HEAD]
} else {
  [--all]
}

let env_vars = if usage_ask in $env {
  {ASK: $env.usage_ask}
} else {
  {}
}

with-env $env_vars { hk run sync ...$job_args ...$file_args }
