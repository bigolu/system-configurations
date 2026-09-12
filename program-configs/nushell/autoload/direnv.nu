use std/config env-conversions

$env.config.hooks.pre_prompt ++= [{
  if (which direnv | is-empty) {
    return
  }
  
  let env_vars = direnv export json
    # This is needed if direnv exits with a non-zero exit code, for example when
    # the .envrc is blocked.
    | (complete).stdout
    | from json
    | default {}
    # If direnv changes the PATH, it will become a string and we need to re-convert it to a list
    | update cells --columns [ PATH ] { do (env-conversions).path.from_string $in }
    | transpose name value
    
  $env_vars
    | where value == null
    | get name
    | hide-env ...$in

  $env_vars
    | where value != null
    | transpose --as-record --header-row
    | default --empty {}
    | load-env
}]
