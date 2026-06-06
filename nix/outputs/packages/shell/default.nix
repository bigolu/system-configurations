{ pkgs, inputs, ... }:
let
  moduleRoot = ../../../home-modules;
  inherit (pkgs.lib) mkForce recursiveUpdate;
in
(pkgs.makePortableHome.override {
  # The full set of locales is pretty big (~220MB) so I'll only include the one that
  # will be used.
  locales = [ "en_US.UTF-8/UTF-8" ];
})
  {
    homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        {
          _module.args = {
            hasGui = false;
            hostName = "portable";
            pkgs = mkForce (recursiveUpdate pkgs (import ./package-overrides.nix pkgs));
          };
          home.username = "bigolu";
          home.homeDirectory = "/not-applicable";
        }
        (moduleRoot + "/common")
        (moduleRoot + "/portable.nix")
      ];
    };
    shell = "fish";
    activation = [
      "fzfSetup"
      "batSetup"
    ];
  }
