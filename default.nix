# This file is part of flake-compat[1]. It allows access to a flake without using the
# flake API. By naming it "default.nix", it will be read automatically by nix-build.
# I have this for the following reasons:
#
# - For compatibility with projects that prefer not to use flakes.
# - For compatibility with projects that can't use flakes because they're using a
#   version of Nix before v2.4.
# - To avoid copying the flake to the store, which happens whenever you use
#   `builtins.getFlake`.
#
# [1]: https://github.com/edolstra/flake-compat
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
) { src = ./.; }).defaultNix
