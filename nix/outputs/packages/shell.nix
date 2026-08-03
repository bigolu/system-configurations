{ pkgs, inputs, ... }:
# This contains only the "en_US.UTF-8/UTF-8" locale.
(pkgs.makePortableHome.override { glibcLocales = pkgs.glibcLocalesUtf8; }) {
  shell = "fish";

  homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      {
        imports = map (path: ../../modules/host + path) [
          /essentials
          /portable
        ];

        portable.outerPkgs = pkgs;
      }
    ];
  };
}
