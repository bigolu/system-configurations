# This file is part of flake-compat[1], a project that provides access to a
# flake without using the (experimental) flake API. I use this because it's
# faster than builtins.getFlake. Though I think when this issue is resolved[2],
# getFlake will be just as fast.
#
# [1]: https://git.lix.systems/lix-project/flake-compat
# [2]: https://github.com/NixOS/nix/issues/3121
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
    copySourceTreeToStore = false;
  }
).defaultNix
