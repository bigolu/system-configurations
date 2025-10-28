{
  pkgs,
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
  imports = [ ./locale.nix ];

  config = mkIf isCiDevShell {
    devshell.packages = with pkgs; [
      # For the `run` steps in CI workflows
      bash-script
    ];

    locale = {
      enable = "ci";
      locale = "en_US.UTF-8/UTF-8";
    };
  };
}
