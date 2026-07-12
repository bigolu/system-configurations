{
  homeManagerPath,
  nvidiaVersion,
  nvidiaSha256,
}:
let
  nixpkgs = import <nixpkgs> {
    overlays = [ ];
    config = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
  };

  inherit (nixpkgs) writeScriptBin;
  inherit (nixpkgs.lib) getExe;

  hmConfig = (import homeManagerPath { }).lib.homeManagerConfiguration {
    pkgs = nixpkgs;
    modules = [
      {
        targets.genericLinux.gpu = {
          enable = true;
          nvidia = {
            enable = true;
            version = nvidiaVersion;
            sha256 = nvidiaSha256;
          };
        };

        # Required
        home = {
          stateVersion = "23.11";
          username = "biggs";
          homeDirectory = "/opt/non-nixos-gpu";
        };
      }
    ];
  };
in
writeScriptBin "start" ''
  #!${getExe nixpkgs.bash}
  ${getExe hmConfig.config.targets.genericLinux.gpu.setupPackage}
''
