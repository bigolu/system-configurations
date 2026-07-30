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
# Use the caches set in the nix config
direnv_export="$(NIX_USER_CONF_FILES="$PWD/program-configs/nix/nix.conf" direnv export bash)"
eval "$direnv_export"

if [[ $OSTYPE == linux* ]]; then
	mise run hk:system-sync "$configuration"
else
	if ! [[ -x /usr/local/bin/brew ]]; then
		# Install homebrew. Source: https://brew.sh/
		homebrew_install_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		/bin/bash -c "$homebrew_install_script"
	fi

	hash_file='nix/outputs/darwinConfigurations/comp_2/modules/comp-2/nix/nix-conf-hash.txt'
	builder_file='nix/outputs/darwinConfigurations/comp_2/modules/comp-2/nix/linux-builder-config-name.txt'
	function undo_file_changes {
		git checkout -- "$hash_file" "$builder_file"
	}
	trap undo_file_changes EXIT

	# Tell nix-darwin the hash of my nix.conf so it can overwrite it. You can find more
	# information in the comment where this file is read.
	shasum -a 256 /etc/nix/nix.conf | cut -d ' ' -f 1 >"$hash_file"

	# Apply the config with the bootstrap builders.
	for builder in bootstrap1 bootstrap2; do
		echo "$builder" >"$builder_file"
		mise run hk:system-sync "$configuration"
	done
fi

HK_SKIP_STEPS='system' mise run sync
