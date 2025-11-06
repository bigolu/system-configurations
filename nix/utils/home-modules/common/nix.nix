{
  pkgs,
  inputs,
  lib,
  repositoryDirectory,
  config,
  ...
}:
let
  inherit (pkgs)
    writeShellApplication
    stdenv
    ;
  inherit (stdenv) isLinux isDarwin;
  inherit (lib)
    hm
    getExe
    makeBinPath
    optionals
    optionalAttrs
    getExe'
    ;

  # TODO: Won't be needed if the daemon auto-reloads:
  # https://github.com/NixOS/nix/issues/8939
  nix-daemon-reload = writeShellApplication {
    name = "nix-daemon-reload";
    text = ''
      if [[ $OSTYPE == linux* ]]; then
        sudo systemctl restart nix-daemon.service
      else
        sudo launchctl kickstart -k system/org.nixos.nix-daemon
      fi
    '';
  };

  syncNixVersionWithSystem =
    let
      nixPackage = pkgs.lix;
      nix = getExe nixPackage;
      nix-env = getExe' nixPackage "nix-env";
    in
    hm.dag.entryAnywhere ''
      PATH="${
        makeBinPath (
          with pkgs;
          [
            coreutils
            jq
          ]
        )
      }:$PATH"

      desired_store_paths=(${nixPackage} ${pkgs.cacert})
      store_path_diff="$(
        comm -3 \
        <(sudo --set-home ${nix} profile list --json | jq --raw-output '.elements | keys[] as $k | .[$k].storePaths[]' | sort) \
        <(printf '%s\n' "''${desired_store_paths[@]}" | sort)
      )"
      if [[ -n "$store_path_diff" ]]; then
        sudo --set-home ${nix} profile remove '.*'
        sudo --set-home ${nix} profile install "''${desired_store_paths[@]}"
        sudo --set-home ${nix-env} --delete-generations old

        # Restart the daemon so we can use the daemon from the version of nix we just
        # installed, but first restart the service manager in case the service
        # definition changed.
        if [[ $OSTYPE == linux* ]]; then
          sudo systemctl daemon-reload
          sudo ${getExe nix-daemon-reload}
        else
          sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
          sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        fi
        while ! nix-store -q --hash ${stdenv.shell} &>/dev/null; do
          echo "waiting for nix-daemon" >&2
          sleep 0.5
        done
      fi
    '';
in
{
  imports = [
    (import "${inputs.nix-index-database}/home-manager-module.nix" inputs.nix-index-database)
  ];

  # Don't make a command_not_found handler
  programs.nix-index.enableFishIntegration = false;

  system = {
    activation = {
      inherit syncNixVersionWithSystem;
    };

    file = {
      "${
        if isLinux then "/usr/share/fish/vendor_conf.d" else "/usr/local/share/fish/vendor_conf.d"
      }/zz-nix-fix.fish".source =
        "${repositoryDirectory}/dotfiles/nix/zz-nix-fix.fish";
    }
    // optionalAttrs isLinux {
      "/etc/profile.d/bigolu-nix-locale-variable.sh".source =
        "${repositoryDirectory}/dotfiles/nix/bigolu-nix-locale-variable.sh";
    };
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-old";
      dates = "monthly";
    };

    registry = {
      # Use the nixpkgs pinned by this project. By default, it pulls the latest
      # version of nixpkgs-unstable.
      nixpkgs.flake = inputs.nixpkgs;
    };
  };

  home = {
    packages =
      with pkgs;
      [
        nix-tree
        nix-melt
        comma
        nix-daemon-reload
        nix-diff
        nix-search-cli
        nix-sweep
        nixpkgs-track
      ]
      ++ optionals isLinux [
        # for breakpointHook:
        # https://nixos.org/manual/nixpkgs/stable/#breakpointhook
        cntr
      ];

    activation = {
      removeOldUserProfileGenerations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        nix-env --delete-generations old
      '';
    };
  };

  xdg.configFile."nix/nix.conf".text = ''
    # Reasons why this should be enabled:
    # https://github.com/NixOS/nix/issues/4442
    always-allow-substitutes = true
    # I don't think this works on macOS:
    # https://github.com/NixOS/nix/issues/7273
    auto-optimise-store = ${if isDarwin then "false" else "true"}
    build-users-group = nixbld
    cores = 0
    experimental-features = nix-command flakes
    extra-sandbox-paths =
    # Disable the global flake registry until they stop fetching it
    # unnecessarily: https://github.com/NixOS/nix/issues/9087
    flake-registry =
    keep-going = true
    keep-outputs = true
    max-jobs = auto
    # Not sure if anything in nix still reads this, but I'll set it just in case.
    nix-path = nixpkgs=flake:nixpkgs
    repl-overlays = ${toString config.repository.fileSettings.relativePathRoot}/nix/repl-overlay.nix
    require-sigs = true
    # I don't think this works on macOS:
    # https://github.com/NixOS/nix/issues/6049#issue-1125028427
    sandbox = ${if isDarwin then "false" else "true"}
    sandbox-fallback = false
    show-trace = true
    substituters = https://cache.nixos.org https://nix-community.cachix.org
    # Don't cache tarballs. This way if I do something like
    # `nix run github:<repo>`, I will always get the up-to-date source
    tarball-ttl = 0
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
    # Don't warn me that the git repository is dirty
    warn-dirty = false
  '';
}
