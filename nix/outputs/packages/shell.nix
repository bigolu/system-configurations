{ pkgs, inputs, ... }:
let
  moduleRoot = ../../home-modules;
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
        # This should be added to every Home Manager configuration.
        # SYNC: hm-base
        {
          imports = [ (moduleRoot + "/essentials") ];
          _module.args = {
            hasGui = false;
            hostName = "portable";
          };
        }

        (import (moduleRoot + "/portable") pkgs)
      ];
    };

    shell = "fish";

    activation = [
      "fzfSetup"
      "batSetup"
    ];
  }
