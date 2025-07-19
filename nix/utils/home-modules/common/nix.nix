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
  inherit (stdenv) isLinux isDarwin;
  inherit (lib)
    hm
    getExe
    makeBinPath
    optionals
    optionalAttrs
    ;

  # TODO: Won't be needed if the daemon auto-reloads:
  # https://github.com/NixOS/nix/issues/8939
  nix-daemon-reload = writeShellApplication {
    name = "nix-daemon-reload";
    text = ''
      kernel="$(uname)"
      if [[ $kernel == 'Linux' ]]; then
        sudo systemctl restart nix-daemon.service
      else
        sudo launchctl kickstart -k system/org.nixos.nix-daemon
      fi
    '';
  };

  syncNixVersionWithSystem =
    let
      # The path set by sudo on Pop!_OS doesn't include nix
      nix = getExe pkgs.nix;
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

      desired_store_paths=(${pkgs.nix} ${pkgs.cacert})
      store_path_diff="$(
        comm -3 \
        <(sudo --set-home ${nix} profile list --json | jq --raw-output '.elements | keys[] as $k | .[$k].storePaths[]' | sort) \
        <(printf '%s\n' "''${desired_store_paths[@]}" | sort)
      )"
      if [[ -n "$store_path_diff" ]]; then
        sudo --set-home ${nix} profile remove --all
        sudo --set-home ${nix} profile install "''${desired_store_paths[@]}"

        # Restart the daemon so we use the daemon from the version of nix we just
        # installed
        sudo --set-home ${getExe nix-daemon-reload}
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

  home.packages =
    with pkgs;
    [
      nix-tree
      nix-melt
      comma
      nix-daemon-reload
      nix-diff
      nix-search-cli
    ]
    ++ optionals isLinux [
      # for breakpointHook:
      # https://nixos.org/manual/nixpkgs/stable/#breakpointhook
      cntr
    ];

  system = {
    activation = {
      inherit syncNixVersionWithSystem;
    };

    file =
      {
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

  repository = {
    xdg = {
      executable."nix" = {
        source = "nix/bin";
        recursive = true;
      };

      configFile."nix/repl-startup.nix".source = "nix/repl-startup.nix";
    };
  };

  nix = {
    gc = {
      automatic = true;
      options = "--delete-old";
    };

    registry = {
      # Use the nixpkgs pinned by this project. By default, it pulls the latest
      # version of nixpkgs-unstable.
      nixpkgs.flake = inputs.nixpkgs;

      # In case something is broken on unstable
      nixpkgs-stable.flake = inputs.nixpkgs-stable;
    };

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Always show the entire stack trace of an error.
      show-trace = true;

      # Don't warn me that the git repository is dirty
      warn-dirty = false;

      # Not sure if anything in nix still reads this, but I'll set it just in case.
      nix-path = [ "nixpkgs=flake:nixpkgs" ];

      # Disable the global flake registry until they stop fetching it
      # unnecessarily: https://github.com/NixOS/nix/issues/9087
      flake-registry = null;

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Reasons why this should be enabled:
      # https://github.com/NixOS/nix/issues/4442
      always-allow-substitutes = true;

      # I don't think this works on macOS:
      # https://github.com/NixOS/nix/issues/7273
      auto-optimise-store = !isDarwin;

      build-users-group = "nixbld";

      cores = 0;

      # Increase the buffer limit to 1GiB since the buffer would often reach the
      # default limit of 64MiB.
      download-buffer-size = 1073741824;

      max-jobs = "auto";

      extra-sandbox-paths = [ ];

      require-sigs = true;

      # I don't think this works on macOS:
      # https://github.com/NixOS/nix/issues/6049#issue-1125028427
      sandbox = !isDarwin;

      sandbox-fallback = false;

      # Don't cache tarballs. This way if I do something like
      # `nix run github:<repo>`, I will always get the up-to-date source
      tarball-ttl = 0;
    };
  };
}
