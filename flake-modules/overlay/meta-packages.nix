_: final: _prev:
let
  myFonts = final.symlinkJoin {
    name = "my-fonts";
    paths = with final; [
      hack-font
      monaspace
      (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
    ];
  };
in
{
  inherit myFonts;
}
