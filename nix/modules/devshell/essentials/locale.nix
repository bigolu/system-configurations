{
  pkgs,
  extraModulesPath,
  lib,
  config,
  ...
}:
let
  inherit (lib) optionalAttrs;
  isCi = config.devshell.name == "ci";
in
{
  imports = [ "${extraModulesPath}/locale.nix" ];

  extra.locale = optionalAttrs isCi {
    # This contains only the "en_US.UTF-8/UTF-8" locale.
    package = pkgs.glibcLocalesUtf8;
  };
}
