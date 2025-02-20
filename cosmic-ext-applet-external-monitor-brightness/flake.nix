{
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        systems = [
          inputs.flake-utils.lib.system.x86_64-linux
        ];

        perSystem =
          { pkgs, ... }:
            {
              devShells.default = pkgs.mkShellNoCC {
                packages = with pkgs; [
                  just
                  rustup
                  pkg-config
                  libxkbcommon
                  systemd
                ];
              };
            };
      }
    );

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
}
