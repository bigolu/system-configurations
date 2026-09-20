#!/usr/bin/env nu

use std/util "path add"

const self = path self

# For nix and nvidia-smi
path add /nix/var/nix/profiles/default/bin /usr/bin

let workspace = if PRJ_ROOT in $env {
	$"($env.PRJ_ROOT)/non-nixos-gpu"
} else {
	/opt/non-nixos-gpu
}
mkdir $workspace
'*' | save --force $"($workspace)/.gitignore"
cd $workspace

if DID_SET_UP_LOGGING not-in $env {
	with-env { DID_SET_UP_LOGGING: 'true' } { nu $self o+e> $"($workspace)/log" }
  exit
}

let last_version_file = $"($workspace)/last-version.txt"
let current_version = (nvidia-smi --query-gpu=driver_version --format=csv,noheader)

if ($last_version_file | path exists) and (open $last_version_file) == $current_version {
	exit
}

let current_package = do {
	let context = if CONTEXT in $env { $env.CONTEXT | from json } else { {} }
	let setup_nix = $context.setupNix? | default ($self | path dirname | path join setup.nix)
	let home_manager = $context.homeManager? | default (nix eval --raw --file $env.PRJ_ROOT inputs.home-manager.outPath)
	let hash = (
		nix store prefetch-file
			--json
			--hash-type sha256
			$'https://download.nvidia.com/XFree86/Linux-x86_64/($current_version)/NVIDIA-Linux-x86_64-($current_version).run'
	)
		| from json
		| get hash
	(
		nix
			build
			--no-link
			--print-out-paths
			--file $setup_nix
			--argstr homeManagerPath $home_manager
			--argstr nvidiaVersion $current_version
			--argstr nvidiaSha256 $hash
	)
}

^$"($current_package)/bin/start"
# We don't want a GC root since tools like nix-sweep delete old GC roots,
# which means it will delete `/etc/tmpfiles.d/non-nixos-gpu.conf`. Instead, we
# install it into the default profile.
rm --force /nix/var/nix/gcroots/non-nixos-gpu.conf
let default_profile = if PRJ_ROOT in $env { $"($workspace)/profile" } else { /nix/var/nix/profiles/default }
let last_package_file = $"($workspace)/last-package.txt"
if ($last_package_file | path exists) {
	nix profile remove (open --raw $last_package_file) --profile $default_profile
}
nix profile install $current_package --profile $default_profile

$current_package | save --force $last_package_file
$current_version | save --force $last_version_file
