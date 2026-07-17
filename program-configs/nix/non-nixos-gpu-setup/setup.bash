#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

export PATH="/nix/var/nix/profiles/default/bin:/usr/bin:${PATH:+:$PATH}"

if [[ -n ${PRJ_ROOT:-} ]]; then
	workspace="$PRJ_ROOT/non-nixos-gpu"
else
	workspace=/opt/non-nixos-gpu
fi
mkdir --parents "$workspace"
echo '*' >"$workspace/.gitignore"
cd "$workspace"

exec >"$workspace/log" 2>&1
set -x

setup_nix=@setupnix@
if [[ ! -e $setup_nix ]]; then
	setup_nix=./setup.nix
fi

home_manager=@homemanager@
if [[ ! -e $home_manager ]]; then
	home_manager="$(nix eval --raw --file "${PRJ_ROOT:?}" inputs.home-manager.outPath)"
fi

last_version_file="$workspace/last-version.txt"
current_version="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"

if [[ ! -e $last_version_file || $(<"$last_version_file") != "$current_version" ]]; then
	sha256="$(
		nix store \
			prefetch-file \
			--json \
			--hash-type sha256 \
			"https://download.nvidia.com/XFree86/Linux-x86_64/$current_version/NVIDIA-Linux-x86_64-$current_version.run" |
			jq -r .hash
	)"
	current_package="$(
		nix \
			build \
			--no-link \
			--print-out-paths \
			--file "$setup_nix" \
			--argstr homeManagerPath "$home_manager" \
			--argstr nvidiaVersion "$current_version" \
			--argstr nvidiaSha256 "$sha256"
	)"
	"$current_package/bin/start"
	if [[ -n ${PRJ_ROOT:-} ]]; then
		default_profile="$workspace/profile"
	else
		default_profile=/nix/var/nix/profiles/default
	fi
	last_package_file="$workspace/last-package.txt"
	if [[ -e $last_package_file ]]; then
		nix profile remove "$(<"$last_package_file")" --profile "$default_profile"
	fi
	nix profile install "$current_package" --profile "$default_profile"
	echo "$current_package" >"$last_package_file"
	echo "$current_version" >"$last_version_file"
fi
