# This file is part of flake-compat[1]. I use it for these reasons:
#   - Until Lix implements lazy trees, this is the only way to access a flake
#     without copying it to the store[2].
#   - It allows my project to be used by projects that don't use flakes.
#
# [1]: https://git.lix.systems/lix-project/flake-compat
# [2]: https://git.lix.systems/lix-project/flake-compat#copying-to-the-store

let
  lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);
  flake-compat-node = lockFile.nodes.${lockFile.nodes.root.inputs.flake-compat};
  flake-compat = builtins.fetchTarball {
    inherit (flake-compat-node.locked) url;
    sha256 = flake-compat-node.locked.narHash;
  };

  flake = import flake-compat {
    src = ./.;
    copySourceTreeToStore = false;
  };
in
flake
// {
  # This is not part of flake-compat. I added it to make it easier to get
  # an output for the current system.
  outputsForCurrentSystem =
    let
      inherit (builtins)
        mapAttrs
        isAttrs
        hasAttr
        currentSystem
        ;
    in
    mapAttrs (
      _name: value:
      if (isAttrs value && hasAttr currentSystem value) then value.${currentSystem} else value
    ) flake.outputs;
}
