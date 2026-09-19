#nix --interpreter nu --packages nushell
#MISE hide=true

def main [] {
  copy_bundle_into_assets (register_asset_directory) (make_shell_bundle)
}

def register_asset_directory []: nothing -> string {
  let dir = mktemp --directory

  if GITHUB_OUTPUT in $env {
    $dir | save --append $env.GITHUB_OUTPUT
  } else {
    $"($dir)\n" | save --append '/dev/stderr'
  }

  $dir
}

def make_shell_bundle []: nothing -> string {
  let gc_root_dir = mktemp --directory
  let derivation = nix eval --raw --file . outputsForCurrentSystem.packages.shell-bundle.drvPath

	# The derivation relies on all the store paths in the bundle while the bundle
	# itself doesn't depend on anything. Therefore, even if we already have the bundle,
	# we'd still need all of the store paths that are in the bundle to make the
	# derivation so we'll add a GC root for the derivation as well.
	nix build --out-link ($gc_root_dir | path join 'derivation-gc-root') $derivation

  let bundle_gc_root = $gc_root_dir | path join 'bundle-gc-root'
  # Ignore the output since it contains the GC root path, not the store path
	nix-store --add-root $bundle_gc_root --realise $derivation | ignore
  $bundle_gc_root | path expand
}

def copy_bundle_into_assets [asset_dir: string, bundle_store_path: string] {
  # Example: /nix/store/<hash>-foo-0.1.0 -> $asset_dir/foo-linux-x86_64
  let destination = $bundle_store_path
    # Remove everything up to, and including, the first `-`. Then the name will
    # be everything from the beginning up until the first dash that is followed by a digit.
    | parse --regex '.*?-(?<name>.*?)-[0-9]*.*'
    | get name.0
    | $"($in)-($nu.os-info.name)-($nu.os-info.arch)"
    | [ $asset_dir $in ] | path join

  cp $bundle_store_path $destination
}
