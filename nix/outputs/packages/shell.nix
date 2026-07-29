{ pkgs, inputs, ... }:
let
  myUtils = import ../../my-utils.nix;
in
# This contains only the "en_US.UTF-8/UTF-8" locale.
(pkgs.makePortableHome.override { glibcLocales = pkgs.glibcLocalesUtf8; }) {
  shell = "fish";

  homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs; };
    modules = with myUtils.modules.home; [
      essentials
      (portable pkgs)
    ];
  };
}
