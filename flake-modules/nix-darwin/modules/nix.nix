{
  config,
  specialArgs,
  pkgs,
  ...
}:
let
  inherit (specialArgs) homeDirectory username;
in
{
  nix = {
    useDaemon = true;

    # Newer versions of nix are backwards compatible with the manifest.json of
    # older versions. Since I don't know which version of nix will be on my
    # host, I'll use latest here to have the best chance at compatibility.
    package = pkgs.nixVersions.latest;

    settings = {
      trusted-users = [
        "root"
        username
      ];

      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
      ];
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
    ${pkgs.bashInteractive}/bin/bash ${specialArgs.flakeInputs.self}/dotfiles/nix/nix-fix/install-nix-fix.bash
  '';
}
