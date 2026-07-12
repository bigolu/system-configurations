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

gc_root="$workspace/gc-root"

if [[ ! -e $last_version_file || $(<"$last_version_file") != "$current_version" ]]; then
	sha256="$(
		nix store \
			prefetch-file \
			--json \
			--hash-type sha256 \
			"https://download.nvidia.com/XFree86/Linux-x86_64/$current_version/NVIDIA-Linux-x86_64-$current_version.run" |
			jq -r .hash
	)"
	package="$(
		nix \
			build \
			--out-link "$gc_root" \
			--print-out-paths \
			--file "$setup_nix" \
			--argstr homeManagerPath "$home_manager" \
			--argstr nvidiaVersion "$current_version" \
			--argstr nvidiaSha256 "$sha256"
	)"
	"$package/bin/start"
	echo "$current_version" >"$last_version_file"
else
	# `nh`[1] and `nix-sweep`[2] can delete GC roots that haven't been
	# modified in a certain amount of time. To avoid having this
	# GC root get deleted, we'll update the modification time.
	#
	# [1]: https://github.com/nix-community/nh
	# [2]: https://github.com/jzbor/nix-sweep
	touch --no-dereference "$gc_root"
fi
