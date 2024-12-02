{
  config,
  specialArgs,
  pkgs,
  lib,
  ...
}:
let
  inherit (specialArgs) homeDirectory flakeInputs;
in
{
  nix = {
    useDaemon = true;
    settings = flakeInputs.self.lib.systemNixSettings { inherit pkgs; };
  };

  launchd.daemons.nix-gc = {
    # To avoid having root directly manipulate the store, explicitly set the daemon.
    # Source: https://docs.lix.systems/manual/lix/stable/installation/multi-user.html#multi-user-mode
    environment.NIX_REMOTE = "daemon";

    serviceConfig.RunAtLoad = false;

    serviceConfig.StartCalendarInterval = [
      # Run GC once a week. Since timers that go off when the computer is off never
      # run, I try to give it more chances to run.
      # source: https://superuser.com/a/546353
      {
        Weekday = 1;
        Hour = 10;
      }
      {
        Weekday = 1;
        Hour = 12;
      }
      {
        Weekday = 1;
        Hour = 16;
      }
      {
        Weekday = 1;
        Hour = 18;
      }
      {
        Weekday = 1;
        Hour = 20;
      }
    ];

    command = lib.getExe (
      pkgs.writeShellApplication {
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
          now="$(date '+%y%m%d')"
          # This to ensure it runs at most once in a day. To learn why I can't
          # just schedule it to run once in a day, check the comment where the schedule
          # is defined.
          if [[ "$last_gc" == "$now" ]]; then
            exit
          fi

          # nix-darwin
          nix-env --profile /nix/var/nix/profiles/system --delete-generations old
          nix-env --profile /nix/var/nix/profiles/default --delete-generations old
          nix-env --profile /nix/var/nix/profiles/per-user/root/profile --delete-generations old
          nix-env --profile ${homeDirectory}/.local/state/nix/profiles/home-manager --delete-generations old
          nix-env --profile ${homeDirectory}/.local/state/nix/profiles/profile --delete-generations old

          nix-collect-garbage --delete-old

          printf '%s' "$now" >"$last_gc_file"
        '';
      }
    );
  };

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
