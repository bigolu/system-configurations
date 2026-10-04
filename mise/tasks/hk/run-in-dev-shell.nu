#nix --interpreter nu --packages nushell
#MISE hide=true
#USAGE arg "<command>" var=#true

def --wrapped main [...command] {

  # Some of the sync jobs may depend on something from the new devshell.
  if $env.IN_GIT_AUTO_SYNC? == 'true' {
    nix run --file . outputsForCurrentSystem.devShells.dev -- ...$command
  } else {
    run-external ...$command
  }
}
