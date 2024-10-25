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

      sandbox = true;
    };
  };

  launchd.daemons.nix-gc = {
    # To avoid having root directly manipulate the store, explicitly set the daemon.
    # Source: https://docs.lix.systems/manual/lix/stable/installation/multi-user.html#multi-user-mode
    environment.NIX_REMOTE = "daemon";

    serviceConfig.RunAtLoad = false;

    serviceConfig.StartCalendarInterval = [
      # Run GC once a month. Since timers that go off when the computer is off never
      # run, I try to give it more chances to run.
      # source: https://superuser.com/a/546353
      {
        Day = 1;
        Hour = 10;
      }
      {
        Day = 1;
        Hour = 12;
      }
      {
        Day = 1;
        Hour = 16;
      }
      {
        Day = 1;
        Hour = 18;
      }
      {
        Day = 1;
        Hour = 20;
      }
    ];

    command = pkgs.writeShellApplication {
      name = "gc";
      runtimeInputs = with pkgs; [
        config.nix.package
        coreutils
        terminal-notifier
      ];
      text = ''
        log="$(mktemp --tmpdir 'nix_garbage_collection_XXXXX')"
        exec 2>"$log" 1>"$log"
        trap 'terminal-notifier -title "Nix Darwin" -message "Garbage collection failed :( Check the logs in $log"' ERR

        last_gc_file='/nix/last-gc.txt'
        if [[ -e "$last_gc_file" ]]; then
          last_gc="$(<"$last_gc_file")"
        else
          last_gc=
        fi
        now="$(date '+%y%m')"
        # This to ensure it runs at most once in a day. To learn why I can't
        # just schedule it to run once in a day, check the comment where the schedule
        # is defined.
        if [[ "$last_gc" == "$now" ]]; then
          exit
        fi

        # nix-darwin
        nix-env --profile /nix/var/nix/profiles/system --delete-generations old
        nix-env --profile /nix/var/nix/profiles/default --delete-generations old
        nix-env --profile ${homeDirectory}/.local/state/nix/profiles/home-manager --delete-generations old
        nix-env --profile ${homeDirectory}/.local/state/nix/profiles/profile --delete-generations old

        nix-collect-garbage --delete-older-than 30d

        printf '%s' "$now" >"$last_gc_file"
      '';
    };
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

  # Workaround for doing the first `darwin-rebuild switch`. Since nix-darwin only
  # overwrites files that it knows the contents of, I have to take the add the hash
  # of my /etc/nix/nix.conf here before doing my first rebuild so it can overwrite
  # it. You can also move the existing nix.conf to another location, but then none of
  # my settings, like substituters, will be applied when I do the first rebuild. So
  # the plan is to temporarily add the hash here and once the first rebuild is done,
  # remove it. There's an open issue for having nix-darwin backup the file and
  # replace it instead of refusing to run[1].
  #
  # Also, this is an internal option so it may change without notice.
  #
  # [1]: https://github.com/LnL7/nix-darwin/issues/149
  environment.etc."nix/nix.conf".knownSha256Hashes = [
    (pkgs.lib.removeSuffix "\n" (builtins.readFile ../nix-conf-hash.txt))
  ];
}
