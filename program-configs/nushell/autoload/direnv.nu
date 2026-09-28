use std/config env-conversions

$env.config.hooks.pre_prompt ++= [
  {
    if (which direnv | is-empty) {
      return
    }

    direnv export json
    # This is needed if direnv exits with a non-zero exit code, for example when
    # the .envrc is blocked.
    | (complete).stdout
    | from json
    | default {}
    # If direnv changes the PATH, it will become a string and we need to re-convert it to a list
    | update cells --columns [PATH] { do (env-conversions).path.from_string $in }
    | transpose name value
    | group-by { if $in.value == null { 'hide' } else { 'load' } }
    | do --env {
      $in.hide?
      | default []
      | get name
      | hide-env ...$in

      $in.load?
      | default []
      | transpose --as-record --header-row
      | default --empty {}
      | load-env
    }
  }
]
