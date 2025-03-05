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

  # Since I use a custom `nix.linux-builder`, I use the linux-builder cached by
  # nixpkgs to build it. So before applying my config for the first time, I need to
  # run 2 bootstrap builders:
  #   bootstrap1 - The builder cached by nixpkgs which will build the next builder.
  #   bootstrap2 - My builder, but with `ephemeral = true` to erase the first builder.
  linuxBuilderConfigs = rec {
    bootstrap1 = { };

    bootstrap2 = myBuilder // {
      ephemeral = true;
    };

    myBuilder = {
      # Setting this will erase the VM state, but is necessary for certain config
      # changes[1]. Only do it when necessary since it would clear the VM's build
      # cache.
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
  linuxBuilderConfigName = removeSuffix "\n" (readFile ./linux-builder-config-name.txt);
  linuxBuilderConfig = linuxBuilderConfigs.${linuxBuilderConfigName};
in
{
  nix = {
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
      systems = [ (replaceStrings [ "darwin" ] [ "linux" ] system) ];
    } // linuxBuilderConfig;
  };

  # Workaround for doing the first `darwin-rebuild switch`. Since nix-darwin only
  # overwrites files that it knows the contents of, I have to add the hash of my
  # /etc/nix/nix.conf here before doing my first rebuild so it can overwrite it. I
  # could also move the existing nix.conf to another location, but then none of my
  # settings, like trusted-users, will be applied when I do the first rebuild. So the
  # plan is to temporarily add the hash here and once the first rebuild is done,
  # remove it. There's an open issue for having nix-darwin backup the file and
  # replace it instead of refusing to run[1].
  #
  # Also, this is an internal option so it may change without notice.
  #
  # [1]: https://github.com/LnL7/nix-darwin/issues/149
  environment.etc."nix/nix.conf".knownSha256Hashes = [
    (removeSuffix "\n" (readFile ./nix-conf-hash.txt))
  ];
}
