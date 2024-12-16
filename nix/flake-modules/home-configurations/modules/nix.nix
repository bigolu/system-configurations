{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;

  # TODO: Won't be needed if the daemon auto-reloads:
  # https://github.com/NixOS/nix/issues/8939
  nix-daemon-reload = pkgs.writeShellApplication {
    name = "nix-daemon-reload";
    text = ''
      if uname | grep -q Linux; then
        sudo systemctl restart nix-daemon.service
      else
        sudo launchctl kickstart -k system/org.nixos.nix-daemon
      fi
    '';
  };

  activationScripts = {
    setLocale = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Add /usr/bin so scripts can access system programs like sudo/apt
      # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
      PATH="$PATH:/usr/bin:/bin"

      path=/etc/profile.d/bigolu-nix-locale-variable.sh
      if [[ ! -e "$path" ]]; then
        sudo mkdir -p "$(dirname "$path")"
        sudo ln --symbolic --force --no-dereference \
          ${config.repository.directory}/dotfiles/nix/bigolu-nix-locale-variable.sh \
          "$path"
      fi
    '';

    syncNixVersionWithSystem =
      let
        # The path set by sudo on Pop!_OS doesn't include nix
        nix = lib.getExe pkgs.nix;
      in
      lib.hm.dag.entryAnywhere ''
        # Add /usr/bin so scripts can access system programs like sudo/apt.
        # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
        PATH="${
          pkgs.lib.makeBinPath (
            with pkgs;
            [
              coreutils
              jq
            ]
          )
        }:$PATH:/usr/bin:/bin"

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
          sudo --set-home ${lib.getExe nix-daemon-reload}
          while ! nix-store -q --hash ${pkgs.stdenv.shell} &>/dev/null; do
            echo "waiting for nix-daemon" >&2
            sleep 0.5
          done
        fi
      '';

    installNixPathFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Add /usr/bin so scripts can access system programs like sudo/apt
      # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
      PATH="$PATH:/usr/bin:/bin"

      script_name=zz-nix-fix.fish

      source=${config.repository.directory}/dotfiles/nix/"$script_name"

      if uname | grep -q Linux; then
        prefix='/usr/share/fish/vendor_conf.d'
      else
        prefix='/usr/local/share/fish/vendor_conf.d'
      fi
      destination="$prefix/$script_name"

      if [[ ! -e "$destination" ]]; then
        sudo mkdir -p "$(dirname "$destination")"
        sudo ln --symbolic --force --no-dereference "$source" "$destination"
      fi
    '';

    installNixGarbageCollectionService = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Add /usr/bin so scripts can access system programs like sudo/apt
      # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
      PATH="$PATH:/usr/bin:/bin"

      service_name='nix-garbage-collection.service'
      if ! systemctl list-unit-files "$service_name" 1>/dev/null 2>&1; then
        sudo systemctl link \
          ${config.repository.directory}/dotfiles/nix/systemd-garbage-collection/"$service_name"
        sudo systemctl enable "$service_name"
      fi

      timer_name='nix-garbage-collection.timer'
      if ! systemctl list-unit-files "$timer_name" 1>/dev/null 2>&1; then
        sudo systemctl link \
          ${config.repository.directory}/dotfiles/nix/systemd-garbage-collection/"$timer_name"
        sudo systemctl enable "$timer_name"
        sudo systemctl start "$timer_name"
      fi
    '';
  };
in
{
  imports = [
    inputs.nix-index-database.hmModules.nix-index
  ];

  # Don't make a command_not_found handler
  programs.nix-index.enableFishIntegration = false;

  home = {
    packages =
      with pkgs;
      [
        nix-tree
        nix-melt
        comma
        nix-daemon-reload
        nix-output-monitor
        nix-diff
        nix-search-cli
      ]
      ++ lib.optionals isLinux [
        # for breakpointHook:
        # https://nixos.org/manual/nixpkgs/stable/#breakpointhook
        cntr
      ];

    activation =
      with activationScripts;
      {
        inherit syncNixVersionWithSystem installNixPathFix;
      }
      // lib.optionalAttrs isLinux {
        inherit setLocale installNixGarbageCollectionService;
      };
  };

  repository = {
    symlink.xdg = {
      executable."nix" = {
        source = "nix/bin";
        recursive = true;
      };

      configFile = {
        "nix/repl-startup.nix".source = "nix/repl-startup.nix";
        "fish/conf.d/zz-nix.fish".source = "nix/zz-nix.fish";
      };
    };
  };

  nix = {
    registry = {
      # Use the nixpkgs in this flake in the system flake registry. By default, it
      # pulls the latest version of nixpkgs-unstable.
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

      allowed-users = [ "*" ];

      # https://github.com/NixOS/nix/issues/4442
      always-allow-substitutes = true;

      # Doesn't work on macOS
      auto-optimise-store = pkgs.stdenv.isLinux;

      build-users-group = "nixbld";

      builders = null;

      cores = 0;

      # Double the default size (64MiB -> 124MiB) since I kept hitting it
      download-buffer-size = 134217728;

      max-jobs = "auto";

      extra-sandbox-paths = [ ];

      require-sigs = true;

      # Doesn't work on macOS
      sandbox = pkgs.stdenv.isLinux;

      sandbox-fallback = false;

      trusted-substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Don't cache tarballs. This way if I do something like
      # `nix run github:<repo>`, I will always get the up-to-date source
      tarball-ttl = 0;
    };
  };
}
