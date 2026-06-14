#nix --interpreter bash --packages bash coreutils run-as-admin nh
#MISE hide=true
#USAGE arg "[config]" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

flags=()
# `usage_ask` is an argument for the `sync` task
if [[ ${usage_ask:-} == 'true' ]]; then
	flags+=(--ask)
fi

config="${usage_config:-$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")}"
if [[ $OSTYPE == linux* ]]; then
	manager='home'
	attr_path="outputsForCurrentSystem.legacyPackages.homeConfigurations.$config"
	flags+=(--backup-extension 'backup')
else
	manager='darwin'
	attr_path="outputs.darwinConfigurations.$config"
fi

run_as_admin="$(type -P run-as-admin)"
run_as_admin_canon="$(readlink --canonicalize "$run_as_admin")"
# The sudo policy on Pop!_OS won't inherit environment variables or let me use
# `--preserve-env`
shopt -s lastpipe
env --null | readarray -d '' env_vars
sudo -- "$run_as_admin_canon" \
	env "${env_vars[@]}" \
	nh "$manager" switch "${flags[@]}" --file nix/flake-compat.nix "$attr_path"
