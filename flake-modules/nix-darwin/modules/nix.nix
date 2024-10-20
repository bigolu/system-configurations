{
  config,
  specialArgs,
  pkgs,
  ...
}:
let
  inherit (specialArgs) homeDirectory root;
  fs = pkgs.lib.fileset;
in
{
  nix = {
    useDaemon = true;

    settings = {
      trusted-users = [
        "root"
      ];

      trusted-substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://bigolu.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="

        # SYNC: SYS_CONF_PUBLIC_KEYS
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "bigolu.cachix.org-1:AJELdgYsv4CX7rJkuGu5HuVaOHcqlOgR07ZJfihVTIw="
      ];

      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Don't cache tarballs. This way if I do something like
      # `nix run github:<repo>`, I will always get the up-to-date source
      tarball-ttl = 0;
    };
  };

  launchd.daemons.nix-gc = {
    environment.NIX_REMOTE = "daemon";
    serviceConfig.RunAtLoad = false;

    serviceConfig.StartCalendarInterval = [
      # once a month
      {
        Day = 1;
        Hour = 0;
        Minute = 0;
      }
    ];

    command = ''
      ${pkgs.dash}/bin/dash -c ' \
        export PATH="${config.nix.package}/bin:''$PATH"; \
        nix-env --profile /nix/var/nix/profiles/system --delete-generations +5; \
        nix-env --profile /nix/var/nix/profiles/default --delete-generations +5; \
        nix-env --profile /nix/var/nix/profiles/per-user/root/profile --delete-generations +5; \
        nix-env --profile ${homeDirectory}/.local/state/nix/profiles/home-manager --delete-generations +5; \
        nix-env --profile ${homeDirectory}/.local/state/nix/profiles/profile --delete-generations +5; \
        nix-collect-garbage --delete-older-than 180d; \
      '
    '';
  };

  system.activationScripts.postActivation.text = ''
    echo >&2 '[bigolu] Installing Nix $PATH fix...'
    ${pkgs.bashInteractive}/bin/bash ${
      fs.toSource {
        root = root + "/dotfiles/nix/nix-fix";
        fileset = root + "/dotfiles/nix/nix-fix";
      }
    }/install-nix-fix.bash

    echo >&2 "[bigolu] Syncing nix-darwin's nix/cacert version with the system..."
    # Use --set-home to avoid sudo's warning that current user doesn't own the home
    # directory.
    PATH="${
      pkgs.lib.makeBinPath (
        with pkgs;
        [
          coreutils
          jq
        ]
      )
    }:$PATH"
    desired_store_paths=(${config.nix.package} ${pkgs.cacert})
    store_path_diff="$(comm -3 <(sudo --set-home nix profile list --json | jq --raw-output '.elements | keys[] as $k | .[$k].storePaths[]' | sort) <(printf '%s\n' "''${desired_store_paths[@]}" | sort))"
    if [[ -n "$store_path_diff" ]]; then
      sudo --set-home nix profile remove --all
      sudo --set-home nix profile install "''${desired_store_paths[@]}"

      # Restart the daemon so we use the daemon from the version of nix we just installed
      sudo --set-home launchctl kickstart -k system/org.nixos.nix-daemon
      # To avoid having root directly manipulate the store, explicitly set the daemon.
      # Source: https://docs.lix.systems/manual/lix/stable/installation/multi-user.html#multi-user-mode
      while ! nix-store --store daemon -q --hash ${pkgs.stdenv.shell} &>/dev/null; do
        echo "waiting for nix-daemon" >&2
        sleep 0.5
      done
    fi
  '';
}
