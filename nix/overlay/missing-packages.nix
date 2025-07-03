{ inputs, ... }:
final: _prev:
let
  inherit (final) fetchzip fetchurl;
  inherit (final.stdenv) isLinux mkDerivation;
  inherit (final.lib) getExe;
  inherit (inputs.flake-utils.lib) system;

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

  # Normally I'd use overrideAttrs, but that wouldn't affect keyd-application-mapper
  keyd =
    let
      version = "2.5.0-${inputs.keyd.shortRev}";

      src = inputs.keyd;

      pypkgs = final.python3.pkgs;

      appMap = pypkgs.buildPythonApplication rec {
        pname = "keyd-application-mapper";
        inherit version src;
        format = "other";

        postPatch = ''
          substituteInPlace scripts/${pname} \
            --replace-fail /bin/sh ${final.runtimeShell}
        '';

        propagatedBuildInputs = with pypkgs; [ xlib ];

        dontBuild = true;

        installPhase = ''
          install -Dm555 -t $out/bin scripts/${pname}
        '';

        meta.mainProgram = "keyd-application-mapper";
      };
    in
    mkDerivation {
      pname = "keyd";
      inherit version src;

      postPatch = ''
        substituteInPlace Makefile \
          --replace-fail /usr/local ""

        substituteInPlace keyd.service.in \
          --replace-fail @PREFIX@ $out
      '';

      installFlags = [ "DESTDIR=${placeholder "out"}" ];

      buildInputs = [ final.systemd ];

      enableParallelBuilding = true;

      postInstall = ''
        ln -sf ${getExe appMap} $out/bin/${appMap.pname}
        rm -rf $out/etc

        # TODO: keyd only links the service if /run/systemd/system exists[1]. I
        # should see if this can be changed.
        #
        # [1]: https://github.com/rvaiya/keyd/blob/9c758c0e152426cab3972256282bc7ee7e2f808e/Makefile#L51
        mkdir -p $out/lib/systemd/system
        cp keyd.service.in $out/lib/systemd/system/keyd.service
      '';

      passthru.tests.keyd = final.nixosTests.keyd;

      meta = with final.lib; {
        description = "Key remapping daemon for Linux";
        license = licenses.mit;
        maintainers = with maintainers; [ alfarel ];
        platforms = platforms.linux;
      };
    };

  # TODO: Remove when nixpkgs gets this version or higher
  lefthook =
    let
      version = "1.11.16";
      os = if isLinux then "Linux" else "MacOS";
      sha256 =
        if isLinux then
          "b4d8ddc85ae1a00c70c26fdca6adc09f1c0982739898ebd3f803b5fd7db005d2"
        else
          "7fe15efd16a839e320788d7f560b2dc006331b0310e0af9b36c6bbc2ed6d1d55";
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
  inherit
    config-file-validator
    keyd
    lefthook
    ;
}
