# This file is part of flake-compat[1]. It allows access to a flake without using the
# flake API. By naming it "shell.nix", it will be read automatically by nix-shell. I
# have this for the following reasons:
#
# - For compatibility with projects that prefer not to use flakes.
# - For compatibility with projects that can't use flakes because they're using a
#   version of Nix before v2.4.
# - It's faster than builtins.getFlake, though I think this will help[2].
#
# [1]: https://github.com/edolstra/flake-compat
# [2]: https://github.com/NixOS/nix/issues/3121
(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  in
  fetchTarball {
    url =
      lock.nodes.flake-compat.locked.url
        or "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
    sha256 = lock.nodes.flake-compat.locked.narHash;
  }
) { src = ./.; }).shellNix
