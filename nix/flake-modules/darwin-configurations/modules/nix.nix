{
  lib,
  username,
  pkgs,
  ...
}:
let
  inherit (lib) removeSuffix;
  inherit (builtins) readFile replaceStrings;
  inherit (pkgs) system;

  linuxBuilderSystem = replaceStrings [ "darwin" ] [ "linux" ] system;
in
{
  nix = {
    useDaemon = true;

    gc = {
      automatic = true;
      options = "--delete-old";
    };

    settings = {
      trusted-users = [ username ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    linux-builder = {
      # For this to work, your user must be a trusted user
      enable = true;

      # TODO: I shouldn't have to set this. The default value causes an eval error
      # because it assumes that `cfg.package.nixosConfig.nixpkgs.hostPlatform` is a
      # set[1], but on my machine it's a string ("x86_64-linux"). According to the
      # nix docs, a string is also a valid value[2] so nix-darwin should be updated
      # to account for it.
      #
      # [1]: https://github.com/LnL7/nix-darwin/blob/6ab392f626a19f1122d1955c401286e1b7cf6b53/modules/nix/linux-builder.nix#L127
      # [2]: https://search.nixos.org/options?channel=24.11&show=nixpkgs.hostPlatform&from=0&size=50&sort=relevance&type=packages&query=nixpkgs.hostPlatform
      systems = [ linuxBuilderSystem ];

      # Setting this will erase the VM state, but is necessary for certain config
      # changes[1]. Only do it when necessary to avoid excessive rebuilds.
      #
      # [1]: https://github.com/LnL7/nix-darwin/pull/850
      # ephemeral = true;
      config.virtualisation = {
        cores = 6;
        darwin-builder = {
          diskSize = 50 * 1024;
          memorySize = 12 * 1024;
        };
      };
    };
  };

  # Workaround for doing the first `darwin-rebuild switch`. Since nix-darwin only
  # overwrites files that it knows the contents of, I have to take the add the hash
  # of my /etc/nix/nix.conf here before doing my first rebuild so it can overwrite
  # it. You can also move the existing nix.conf to another location, but then none of
  # my settings, like trusted-users, will be applied when I do the first rebuild. So
  # the plan is to temporarily add the hash here and once the first rebuild is done,
  # remove it. There's an open issue for having nix-darwin backup the file and
  # replace it instead of refusing to run[1].
  #
  # Also, this is an internal option so it may change without notice.
  #
  # [1]: https://github.com/LnL7/nix-darwin/issues/149
  environment.etc."nix/nix.conf".knownSha256Hashes = [
    (removeSuffix "\n" (readFile ../nix-conf-hash.txt))
  ];
}
