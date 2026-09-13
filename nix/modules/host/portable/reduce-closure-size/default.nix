{
  _class,
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkForce
    hm
    recursiveUpdate
    types
    mkOption
    ;
  inherit (config.portable) outerPkgs;
in
{
  homeManager = {
    options.portable.outerPkgs = mkOption {
      type = types.attrs;
      description = "A package set from outside of the module args, this way we can replace the `pkgs` module arg with it without causing infinite recursion.";
    };

    config = {
      _module.args.pkgs = mkForce (recursiveUpdate outerPkgs (import ./package-overrides.nix outerPkgs));

      # Only include the "en_US.UTF-8/UTF-8" locale.
      i18n.glibcLocales = pkgs.glibcLocalesUtf8;

      # Remove the dependency on systemd.
      home.activation.reloadSystemd = mkForce (hm.dag.entryAnywhere "");

      # Remove the dependency on `sd-switch`.
      systemd.user.startServices = mkForce false;

      # Remove shared-mime-info.
      xdg.mime.enable = mkForce false;

      # Remove the flake registry.
      nix.enable = false;
    };
  };
}
.${toString _class}
