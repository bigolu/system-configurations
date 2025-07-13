# This file is part of flake-compat[1], a project that provides access to a flake
# without using the experimental flake API. I use this instead of `builtins.getFlake`
# since it allows me to access the flake without copying it to the store. This has
# two advantages:
#   - Performance
#   - Avoids execessively invalidating cached-nix-shell's (CNS) cache. CNS works by
#     tracing all files accessed while evaluating the nix shell. The package set used
#     by CNS, nixpkgs-for-nix-shell.nix, imports this file to get the flake inputs.
#     If we copied the source tree to the store, then all the files in the git
#     repository, and many files in .git, would be included in the trace which would
#     lead to more cache invalidations. This is due to flake's builtin gitignore
#     support.
#
# Flake-Compat also seems to fetch inputs more lazily which is especially useful in
# CI.
#
# There's an open issue[2] in CppNix for copying flakes to the store lazily, but Lix
# has no plans to implement it[3] so I'll stick with flake-compat.
#
# [1]: https://git.lix.systems/lix-project/flake-compat
# [2]: https://github.com/NixOS/nix/issues/3121
# [3]: https://git.lix.systems/lix-project/flake-compat#copying-to-the-store

(import
  (
    let
      lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
      inherit (lock.nodes.flake-compat.locked) narHash rev url;
    in
    builtins.fetchTarball {
      url = "${url}/archive/${rev}.tar.gz";
      sha256 = narHash;
    }
  )
  {
    src = ../../.;
    # See the comment at the top of the file for why this is done.
    copySourceTreeToStore = false;
  }
).defaultNix
