{
  pkgs,
  inputs,
  lib,
  repositoryDirectory,
  utils,
  hasGui,
  ...
}:
let
  inherit (pkgs) replaceVars writeTextDir resholve;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  inherit (lib)
    optionalString
    getExe
    readFile
    optionals
    ;
  inherit (utils) projectRoot;

  nonNixosGpuRoot = projectRoot + /program-configs/nix/non-nixos-gpu-setup;
  nonNixosGpuService =
    let
      pname = "setup";
      setupBash = resholve.mkDerivation {
        inherit pname;
        version = "0.1.0";
        src = replaceVars (nonNixosGpuRoot + /setup.bash) {
          setupnix = nonNixosGpuRoot + /setup.nix;
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
            "$package" = true;
          };
          fake.external = [
            "nix"
            "nvidia-smi"
          ];
        };
      };
      nonNixosGpuServiceName = "non-nixos-gpu-biggs.service";
      nonNixosGpuServiceTemplate = nonNixosGpuRoot + /non-nixos-gpu-biggs.service;
      processedTemplate = replaceVars nonNixosGpuServiceTemplate { setupbash = getExe setupBash; };
    in
    # This way the basename of the file will be `nonNixosGpuServiceName` which is
    # necessary for `config.system.systemd.units`.
    "${writeTextDir nonNixosGpuServiceName (readFile processedTemplate)}/${nonNixosGpuServiceName}";
in
{
  imports = [ (import "${inputs.nix-index-database}/home-manager-module.nix") ];

  # Don't make a command_not_found handler
  programs.nix-index.enableFishIntegration = false;

  fileWrapper.xdg.configFile = {
    "nix/repl-overlay.nix".source = "nix/repl-overlay.nix";
    "nix/nix.conf".source = "nix/nix.conf";
  };

  system = {
    file = {
      "/usr${optionalString isDarwin "/local"}/share/fish/vendor_conf.d/zz-nix-fix.fish".source =
        "${repositoryDirectory}/program-configs/nix/zz-nix-fix.fish";
    };

    systemd.units = optionals (isLinux && hasGui) [
      nonNixosGpuService
      (nonNixosGpuRoot + /non-nixos-gpu-biggs.path)
    ];
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-old";
      dates = "monthly";
    };

    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  home = {
    packages = with pkgs; [
      nix-tree
      nix-melt
      lixPackageSet.comma
      nix-diff
      nix-search-cli
      nix-sweep
      nixpkgs-track
      dix
    ];

    activation = {
      removeOldUserProfileGenerations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        nix-env --delete-generations old
      '';
    };
  };
}
