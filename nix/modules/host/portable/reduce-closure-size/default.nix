{
  _class,
  lib,
  config,
  pkgs,
  ...
}:
{
  homeManager =
    let
      inherit (lib)
        mkForce
        hm
        recursiveUpdate
        types
        mkOption
        ;
      inherit (config.bigolu) outerPkgs;
    in
    {
      options.bigolu.outerPkgs = mkOption {
        type = types.attrs;
        description = "A package set from outside of the module args, this way we can replace the `pkgs` module arg with it without causing infinite recursion.";
      };

      config = {
        # We don't use the `pkgs` module argument to avoid infinite recursion.
        _module.args.pkgs = mkForce (recursiveUpdate outerPkgs (import ./package-overrides.nix outerPkgs));

        # This contains only the "en_US.UTF-8/UTF-8" locale.
        i18n.glibcLocales = pkgs.glibcLocalesUtf8;

        # fishMinimal doesn't include Python which means the features listed here won't
        # work: https://github.com/NixOS/nixpkgs/pull/387070#issuecomment-2700435274
        programs.fish.package = pkgs.fishMinimal;

        home.activation.reloadSystemd = mkForce (hm.dag.entryAnywhere "");

        # This removes the dependency on `sd-switch`.
        systemd.user.startServices = mkForce false;

        xdg.mime.enable = mkForce false;

        # to remove the flake registry
        nix.enable = false;
      };
    };
}
.${toString _class}
