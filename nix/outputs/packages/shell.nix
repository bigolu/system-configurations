{ pkgs, inputs, ... }:
let
  modulesPath = ../../modules/host;
in
# This contains only the "en_US.UTF-8/UTF-8" locale.
(pkgs.makePortableHome.override { glibcLocales = pkgs.glibcLocalesUtf8; }) {
  shell = "fish";

  homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      {
        imports = [
          (modulesPath + /essentials)
          (modulesPath + /portable)
        ];

        portable.outerPkgs = pkgs;
      }
    ];
  };
}
