# Make sure everything builds. This is necessary since I use nixpkgs-unstable.

set -o errexit
set -o nounset
set -o pipefail

# Build devShells
nix flake show --json |
  jq ".devShells.\"$(nix show-config system)\"|keys[]" |
  xargs -I {} nix develop .#{} --command bash -c ':'

# Build packages. We don't need to build the activation packages in
# legacyPackages.* since they are included in the default package i.e. the
# meta-package containing all packages to cache.
nix flake show --json |
  jq ".packages.\"$(nix show-config system)\"|keys[]" |
  # Allow unfree since the terminal* packages use nvidia drivers
  NIXPKGS_ALLOW_UNFREE=1 xargs -I {} nix build --impure --no-link .#{}
