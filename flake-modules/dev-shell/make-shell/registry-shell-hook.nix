{ pkgs, self }:
let
  # Adapted from home-manager:
  # https://github.com/nix-community/home-manager/blob/2f23fa308a7c067e52dfcc30a0758f47043ec176/modules/misc/nix.nix#L215
  registry = (pkgs.formats.json { }).generate "registry.json" {
    version = 2;
    flakes = [
      {
        exact = true;
        from = {
          id = "local";
          type = "indirect";
        };
        to = {
          type = "path";
          path = self.outPath;
          inherit (self) lastModified narHash;
        };
      }
    ];
  };
in
''
  # TODO: Ensure it ends in a newline so nix-develop-gha works properly.
  # nix-develop-gha needs a trailing newline because of the way multi-line
  # environment variables are set in GitHub Actions. Ideally, it would add the
  # newline if it wasn't present.
  export NIX_CONFIG+=$'\nflake-registry = ${registry}\n'
''
