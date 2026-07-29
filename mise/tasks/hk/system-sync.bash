#nix --interpreter bash --packages bash coreutils s nh system-manager dix ripgrep
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

	function print_logs {
		id="$(systemctl show -p InvocationID --value "home-manager-$USER.service")"
		journalctl --no-pager --output cat _SYSTEMD_INVOCATION_ID="$id" |
			rg --invert-match pam_unix |
			rg --invert-match COMMAND=
	}
	trap print_logs EXIT
else
	flags=()
	# `usage_ask` is an argument for the `sync` task
	if [[ ${usage_ask:-} == 'true' ]]; then
		flags+=(--ask)
	fi

	command+=(nh darwin switch --show-activation-logs "${flags[@]}" --file . "outputs.darwinConfigurations.$config")
fi

# The default sudoers config on Pop!_OS doesn't allow most environment variables
# to be inherited.
shopt -s lastpipe
env --null | readarray -d '' env_vars
s="$(type -P s)"
sudo "$s" env "${env_vars[@]}" "${command[@]}"
