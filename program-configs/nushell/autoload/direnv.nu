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
    | do --env {
      $in
      | record where value == null
      | columns
      | hide-env ...$in

      $in
      | record where value != null
      # If direnv changes the PATH, it will become a string and we need to re-convert it to a list
      | record apply { PATH: { do (env-conversions).path.from_string $in } }
      | load-env
    }
  }
]
