{
  pkgs,
  lib,
  myUtils,
  inputs,
  hasGui,
  ...
}:
let
  inherit (pkgs) linkFarm resholve replaceVars;
  inherit (lib) getExe optionalAttrs;
  inherit (myUtils) projectRoot;

  nonNixosGpuRoot = projectRoot + /program-configs/nix/non-nixos-gpu-setup;

  nonNixosGpuService =
    let
      pname = "setup";
      setupBash = resholve.mkDerivation {
        inherit pname;
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
      };
    in
    replaceVars (nonNixosGpuRoot + /non-nixos-gpu-biggs.service) { setupbash = getExe setupBash; };
in
{
  systemd = optionalAttrs hasGui {
    packages = [
      (linkFarm "non-nixos-gpu-setup-units" {
        "lib/systemd/system/non-nixos-gpu-biggs.service" = nonNixosGpuService;
        "lib/systemd/system/non-nixos-gpu-biggs.path" = nonNixosGpuRoot + /non-nixos-gpu-biggs.path;
      })
    ];
    paths.non-nixos-gpu-biggs.wantedBy = [ "multi-user.target" ];
  };
}
