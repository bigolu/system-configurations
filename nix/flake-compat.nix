# This file is part of flake-compat[1], a project that provides access to a flake
# without using the experimental flake API. I use this instead of `builtins.getFlake`
# since it allows me to access the flake without copying it to the store. This has
# two advantages:
#   - Performance
#   - Avoids execessively invalidating cached-nix-shell's (CNS) cache. CNS works
#     by tracing all files accessed while evaluating the nix shell. The flake
#     API copies the source tree to the store so all the files in the git
#     repository, and many files in .git, would be included in the trace which
#     would lead to more cache invalidations. This is due to flake's builtin
#     gitignore support.
#
# There's an open issue[2] in CppNix for copying flakes to the store lazily, but Lix
# has no plans to implement it anytime soon[3] so I'll stick with flake-compat.
#
# [1]: https://git.lix.systems/lix-project/flake-compat
# [2]: https://github.com/NixOS/nix/issues/3121
# [3]: https://git.lix.systems/lix-project/flake-compat#copying-to-the-store

let
  lockFile = builtins.fromJSON (builtins.readFile ../flake.lock);
  flake-compat-node = lockFile.nodes.${lockFile.nodes.root.inputs.flake-compat};
  flake-compat = builtins.fetchTarball {
    inherit (flake-compat-node.locked) url;
    sha256 = flake-compat-node.locked.narHash;
  };

  flake = import flake-compat {
    src = ../.;
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
      # TODO: (On lix 2.95.1) If you call `mapAttrs` with an attrset that has a `__functor` attribute, it tries to call it.
      # It doesn't happen in the REPL, but it does happen if you run `nix build --file flake.compat outputsForCurrentSystem.devShells.dev`.
      flakeOutputsWithoutFunctor = builtins.removeAttrs flake.outputs [ "__functor" ];
    in
    mapAttrs (
      _name: value:
      if (isAttrs value && hasAttr currentSystem value) then value.${currentSystem} else value
    ) flakeOutputsWithoutFunctor;
}
