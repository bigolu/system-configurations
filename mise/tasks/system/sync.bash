#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter home-manager darwin-rebuild nix-output-monitor coreutils run-as-admin
#MISE hide=true
#USAGE arg "[config]" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# TODO: It would be nice if these tools accepted a file and an attribute path, like
# the new nix CLI.

config="${usage_config:-$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")}"
run_as_admin="$(type -P run-as-admin)"

# Get the password now before `nom` is run since `nom`'s output will hide the
# password input prompt. We have to use `run-as-admin` so that this doesn't require
# the password when `run-as-admin` is in the sudoers file.
sudo -- "$run_as_admin" true

if [[ $OSTYPE == linux* ]]; then
  # sudo policy on Pop!_OS won't let me use `--preserve-env`
  env_vars=()
  readarray -t vars <<<"$(
    set -o posix
    export -p
  )"
  for var in "${vars[@]}"; do
    # Remove everything from the first `=` onwards
    var="${var%%=*}"
    # Remove `export `
    var="${var:7}"
    env_vars+=("$var=${!var}")
  done

  activationScript="$(nix build --no-link --print-out-paths --file . "homeConfigurations.$config.activationPackage")/activate"
  sudo -- "$run_as_admin" \
    env "${env_vars[@]}" HOME_MANAGER_BACKUP_EXT='backup' "$activationScript"
else
  temp="$(mktemp --suffix '.nix')"
  echo "(import $PWD {}).darwinConfigurations.$config" >"$temp"
  sudo -- "$run_as_admin" \
    sudo darwin-rebuild switch -I "darwin=$temp"
fi |& nom
