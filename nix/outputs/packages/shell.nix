{ pkgs, inputs, ... }:
let
  moduleRoot = ../../modules/home;
in
# This contains only the "en_US.UTF-8/UTF-8" locale.
(pkgs.makePortableHome.override { glibcLocales = pkgs.glibcLocalesUtf8; }) {
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
