{
  lib,
  username,
  ...
}:
let
  inherit (lib) removeSuffix;
  inherit (builtins) readFile;
in
{
  nix = {
    useDaemon = true;

    gc = {
      automatic = true;
      options = "--delete-old";
    };

    settings = {
      trusted-users = [
        "root"
        username
      ];

      experimental-features = [
        "nix-command"
        "flakes"
      ];
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
