{ _class, lib, ... }:
{
  homeManager =
    let
      inherit (lib) mkForce;
    in
    {
      imports = [ ./reduce-closure-size ];

      # Home Manager requires that these be set
      home = {
        username = "bigolu";
        homeDirectory = "/not-applicable";
      };

      # I want a self contained executable so I can't have symlinks that point
      # outside the Nix store.
      fileWrapper.settings.editableInstall = mkForce false;
    };
}
.${toString _class}
