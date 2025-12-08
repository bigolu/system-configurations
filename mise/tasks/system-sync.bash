#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils run-as-admin nh
#USAGE arg "[config]" help="The name of the configuration to apply"
#USAGE flag "-a --ask" help="Show diff and confirm before syncing" long_help="Show a diff of the current and new generation and get confirmation before syncing."

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

flags=()
if [[ ${usage_ask:-} == 'true' ]]; then
  flags+=(--ask)
fi

config="${usage_config:-$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")}"
if [[ $OSTYPE == linux* ]]; then
  manager='home'
  attr_path="homeConfigurations.$config"
  flags+=(--backup-extension 'backup')
else
  manager='darwin'
  attr_path="darwinConfigurations.$config"
fi

run_as_admin="$(type -P run-as-admin)"
# The sudo policy on Pop!_OS won't inherit environment variables or let me use
# `--preserve-env`
shopt -s lastpipe
env --null | readarray -d '' env_vars
sudo -- "$run_as_admin" \
  env "${env_vars[@]}" \
  nh "$manager" switch "${flags[@]}" --file . "$attr_path"
