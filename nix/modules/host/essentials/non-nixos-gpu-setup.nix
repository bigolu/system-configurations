{
  _class,
  pkgs,
  lib,
  myUtils,
  inputs,
  ...
}:
{
  "" =
    let
      inherit (pkgs) linkFarm resholve replaceVars;
      inherit (lib) getExe;
      inherit (myUtils) programConfigRoot;

      nonNixosGpuRoot = programConfigRoot + /nix/non-nixos-gpu-setup;

      nonNixosGpuService = replaceVars (nonNixosGpuRoot + /non-nixos-gpu-x.service) {
        setupbash = getExe (
          resholve.mkDerivation rec {
            pname = "setup";
            version = "0.1.0";
            src = replaceVars (nonNixosGpuRoot + /setup.bash) {
              setupnix = "${nonNixosGpuRoot + /setup.nix}";
              homemanager = inputs.home-manager;
            };
            meta.mainProgram = pname;
            dontUnpack = true;
            installPhase = ''
              install -D $src $out/bin/${pname}
            '';
            solutions.default = {
              scripts = [ "bin/${pname}" ];
              interpreter = "${pkgs.bash}/bin/bash";
              inputs = with pkgs; [
                coreutils
                jq
              ];
              keep = {
                "$current_package" = true;
              };
              fake.external = [
                "nix"
                "nvidia-smi"
              ];
            };
          }
        );
      };
    in
    {
      systemd = {
        packages = [
          (linkFarm "non-nixos-gpu-setup-units" {
            "lib/systemd/system/non-nixos-gpu-x.service" = nonNixosGpuService;
            "lib/systemd/system/non-nixos-gpu-x.path" = nonNixosGpuRoot + /non-nixos-gpu-x.path;
          })
        ];
        # SYNC: non-nixos-gpu-path-wanted-by
        paths.non-nixos-gpu-x.wantedBy = [ "multi-user.target" ];
        # SYNC: non-nixos-gpu-service-wanted-by
        services.non-nixos-gpu-x.wantedBy = [ "multi-user.target" ];
      };
    };
}
.${toString _class}
