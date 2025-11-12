{
  pkgs,
  inputs,
  lib,
  repositoryDirectory,
  ...
}:
let
  inherit (pkgs)
    writeShellApplication
    stdenv
    ;
  inherit (stdenv) isLinux;
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

  repository.xdg.configFile = {
    "nix/repl-overlay.nix".source = "nix/repl-overlay.nix";
    "nix/nix.conf".source = "nix/nix.conf";
  };

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
}
