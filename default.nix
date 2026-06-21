# This file is part of flake-compat[1], a project that provides access to a flake
# without using the experimental flake API. I use this instead of `builtins.getFlake`
# since it allows me to access the flake without copying it to the store.
#
# There's an open issue[2] in CppNix for copying flakes to the store lazily, but Lix
# has no plans to implement it anytime soon[3] so I'll stick with flake-compat.
#
# [1]: https://git.lix.systems/lix-project/flake-compat
# [2]: https://github.com/NixOS/nix/issues/3121
# [3]: https://git.lix.systems/lix-project/flake-compat#copying-to-the-store

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
