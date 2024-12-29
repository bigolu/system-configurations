{ inputs, ... }:
final: _prev:
let
  inherit (final) fetchurl fetchzip;
  inherit (final.stdenv) isLinux mkDerivation;
  inherit (inputs.flake-utils.lib) system;

  catp = mkDerivation {
    pname = "catp";
    version = "0.2.0";
    src = fetchzip {
      url = "https://github.com/rapiz1/catp/releases/download/v0.2.0/catp-x86_64-unknown-linux-gnu.zip";
      sha256 = "sha256-U7h/Ecm+8oXy8Zr+Rq25eSiZw/2/GuUCFvnCtuc7pT8=";
    };
    installPhase = ''
      mkdir -p $out/bin
      cp $src/catp $out/bin/
    '';
    meta = {
      platforms = with system; [
        x86_64-linux
      ];
    };
  };

  config-file-validator = mkDerivation {
    pname = "config-file-validator";
    version = "1.8.0";
    src = fetchzip {
      url = "https://github.com/Boeing/config-file-validator/releases/download/v1.8.0/validator-v1.8.0-${
        if isLinux then "linux" else "darwin"
      }-amd64.tar.gz";
      sha256 =
        if isLinux then
          "sha256-3cxk+gC0V54VwrIyGFHmIs4TD8IqqixnPDbs+XTG0CU="
        else
          "sha256-QxNAbdzX5cBMj+Hu1tMSD1em69Xl/CyDBnrQz3DUNUs=";
      stripRoot = false;
    };
    installPhase = ''
      mkdir -p $out/bin
      cp $src/validator $out/bin/
    '';
    meta = {
      platforms = with system; [
        x86_64-linux
        x86_64-darwin
      ];
    };
  };

  lefthook =
    let
      version = "1.10.1";
      os = if isLinux then "Linux" else "MacOS";

      sha256 =
        if isLinux then
          "1dvkv9kqrd1885clf4v6y8c2pg252qyllrivd85csl5f8fnzq3qq"
        else
          "1x8cwih5acy8l3cz17nqx9hvrlzxqxidnyrbn3jd0nf9lbninnq6";
    in
    mkDerivation {
      pname = "lefthook";
      inherit version;

      src = fetchurl {
        url = "https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_${os}_x86_64";
        inherit sha256;
      };

      phases = [
        "installPhase"
        "patchPhase"
      ];

      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/lefthook
        chmod +x $out/bin/lefthook

        mkdir -p $out/share/fish/vendor_completions.d
        $out/bin/lefthook completion fish > $out/share/fish/vendor_completions.d/lefthook.fish
      '';

      meta = {
        platforms = with system; [
          x86_64-linux
          x86_64-darwin
        ];
      };
    };
in
{
  inherit catp config-file-validator lefthook;
}
