#nix --interpreter nu --packages nushell
#MISE hide=true
#USAGE arg "<command>" var=#true

def main [...command] {

  # Some of the sync jobs may depend on something from the new devshell.
  if IN_GIT_AUTO_SYNC in $env and $env.IN_GIT_AUTO_SYNC == 'true' {
    nix run --file . outputsForCurrentSystem.devShells.dev -- ...$command
  } else {
    run-external ...$command
  }
}
