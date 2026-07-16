#nix --interpreter bash --packages bash coreutils run-as-admin nh system-manager dix ripgrep
#MISE hide=true
#USAGE arg "[config]" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

command=()

config="${usage_config:-$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")}"
if [[ $OSTYPE == linux* ]]; then
	# `usage_ask` is an argument for the `sync` task
	if [[ ${usage_ask:-} == 'true' ]]; then
		old_config=/nix/var/nix/profiles/system-manager-profiles/system-manager
		new_config="$(nix build --no-link --print-out-paths --file . "outputs.systemConfigs.$config")"
		dix "$old_config" "$new_config"
		read -r -p 'Apply the configuration? (y/n): ' response
		# Move to a new line after character input
		echo
		case $response in
			y)
				;;
			n)
				exit
				;;
			*)
				echo 'Invalid input' >&2
				exit
				;;
		esac
	fi

	command+=(system-manager switch --sudo --flake ".#systemConfigs.$config")

	# `usage_verbose` is an argument for the `sync` task
	if [[ ${usage_verbose:-} == 'true' ]]; then
		function print_logs {
			id="$(systemctl show -p InvocationID --value home-manager-biggs.service)"
			journalctl --no-pager --output cat _SYSTEMD_INVOCATION_ID="$id" |
				rg --invert-match pam_unix |
				rg --invert-match COMMAND=
		}
		trap print_logs EXIT
	fi
else
	flags=()
	# `usage_ask` is an argument for the `sync` task
	if [[ ${usage_ask:-} == 'true' ]]; then
		flags+=(--ask)
	fi
	# `usage_verbose` is an argument for the `sync` task
	if [[ ${usage_verbose:-} == 'true' ]]; then
		flags+=(--show-activation-logs)
	fi

	command+=(nh darwin switch "${flags[@]}" --file . "outputs.darwinConfigurations.$config")
fi

run_as_admin="$(type -P run-as-admin)"
run_as_admin_canon="$(readlink --canonicalize "$run_as_admin")"
# The sudo policy on Pop!_OS won't inherit environment variables or let me use
# `--preserve-env`
shopt -s lastpipe
env --null | readarray -d '' env_vars
sudo -- "$run_as_admin_canon" \
	env "${env_vars[@]}" \
	"${command[@]}"
