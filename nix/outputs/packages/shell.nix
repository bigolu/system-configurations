{ pkgs, inputs, ... }:
let
  moduleRoot = ../../modules/home;
in
# This contains only the "en_US.UTF-8/UTF-8" locale.
(pkgs.makePortableHome.override { glibcLocales = pkgs.glibcLocalesUtf8; }) {
  shell = "fish";
  activation = [ "fzfSetup" ];

  homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      (import (moduleRoot + /essentials) {
        hasGui = false;
        hostName = "portable";
      })
      (import (moduleRoot + "/portable") pkgs)
    ];
  };
}
