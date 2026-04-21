{
  lib,
  pkgs,
  hasGui,
  utils,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) mkMerge mkIf;
  inherit (pkgs) symlinkJoin;
  inherit (utils) unstableVersion;

  myFonts = symlinkJoin {
    pname = "my-fonts";
    version = unstableVersion;
    paths = with pkgs; [
      nerd-fonts.symbols-only
      jetbrains-mono
      (iosevka.override {
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
      })
    ];
  };
in
mkMerge [
  (mkIf hasGui {
    home.packages = [ myFonts ];
  })
  (mkIf (isLinux && hasGui) {
    fonts.fontconfig.enable = true;
    # VS Code can't read my fonts from Nix despite them showing up in fontconfig so I
    # make a symlink to them from a location that VS Code _can_ read.
    xdg.dataFile."fonts".source = "${myFonts}/share/fonts";
  })
]
