{
  pkgs,
  extraModulesPath,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    hasPrefix
    ;

  isCiDevShell = hasPrefix "ci-" config.devshell.name;
in
{
  imports = [ "${extraModulesPath}/locale.nix" ];

  config = mkIf isCiDevShell {
    devshell.packages = with pkgs; [
      # For the `run` steps in CI workflows
      bash-script
    ];

    extra.locale = {
      lang = "en_US.UTF-8";
      # The full set of locales is pretty big (~220MB) so I'll only include the one
      # that will be used.
      package = pkgs.glibcLocales.override {
        allLocales = false;
        locales = [ "en_US.UTF-8/UTF-8" ];
      };
    };
  };
}
