set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

configuration="${1:?}"

project_dir=~/code/system-configurations
if [[ ! -d $project_dir ]]; then
	git clone https://github.com/bigolu/system-configurations.git "$project_dir"
fi
cd "$project_dir"

if [[ ! -e .envrc ]]; then
	echo "source .envrc-recommended.bash" >.envrc
fi
direnv allow
conf="$PWD/program-configs/nix/nix.conf"
[[ -e $conf ]]
# Use the caches set in the nix config
direnv_export="$(NIX_USER_CONF_FILES="$conf" direnv export bash)"
eval "$direnv_export"

# Besides passing positional arguments, this is done separately from other syncs
# since it may prompt the user and `hk`, which is called by `mise run sync`,
# seems to have a bug where it can't take user input despite me enabling the
# `interactive` setting.
mise run hk:system-sync "$configuration"

HK_SKIP_STEPS='system' mise run sync
