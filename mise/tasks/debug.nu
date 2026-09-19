#nix --interpreter nu --packages nushell
#MISE description="Start portable home in an empty environment"
#USAGE flag "-b --bundle" help="Use `nix bundle` (slower)"

def --wrapped main [...$args] {
  let shell = if $env.usage_bundle? == 'true' {
    nix build --no-link --print-out-paths --file . outputsForCurrentSystem.packages.shell-bundle
  } else {
    # Use a glob to avoid hard coding the program name
    glob $"(nix build --print-out-paths --no-link --file . outputsForCurrentSystem.packages.shell)/bin/*"
      | get 0
  }

  let temp_home = mktemp --directory

  $env
    | columns
    | where $it not-in [ PWD TERM ]
    | hide-env ...$in

  try {
    with-env { HOME: $temp_home } { ^$shell }
  } finally {
    rm --recursive --force $temp_home
  }
}
