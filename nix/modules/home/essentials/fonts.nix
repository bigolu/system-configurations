{
  lib,
  pkgs,
  hasGui,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  inherit (lib) optional;
in
{
  fonts.fontconfig.enable = isLinux && hasGui;

  home.packages = optional hasGui (
    pkgs.iosevka.override {
      set = "Custom";
      privateBuildPlan = ''
        [buildPlans.IosevkaCustom]
        family = "Iosevka Custom"
        spacing = "fixed"
        serifs = "sans"
        noCvSs = true
        exportGlyphNames = false

        [buildPlans.IosevkaCustom.weights.Regular]
        shape = 400
        menu = 400
        css = 400

        [buildPlans.IosevkaCustom.weights.Bold]
        shape = 700
        menu = 700
        css = 700

        [buildPlans.IosevkaCustom.slopes.Upright]
        angle = 0
        shape = "upright"
        menu = "upright"
        css = "normal"

        [buildPlans.IosevkaCustom.slopes.Oblique]
        angle = 9.4
        shape = "oblique"
        menu = "italic"
        css = "italic"
      '';
    }
  );
}
