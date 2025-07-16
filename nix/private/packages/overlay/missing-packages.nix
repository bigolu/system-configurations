{ pins, ... }:
final: _prev:
let
  inherit (builtins) substring;
  inherit (final.stdenv) isLinux mkDerivation;
  inherit (final.lib) getExe;

  config-file-validator = mkDerivation {
    pname = "config-file-validator";
    version = "1.8.0";
    src = pins.${"config-file-validator-${if isLinux then "linux" else "darwin"}"};
    installPhase = ''
      mkdir -p $out/bin
      cp $src/validator $out/bin/
    '';
    meta = {
      platforms = [
        "x86_64-linux"
        "x86_64-darwin"
      ];
    };
  };

  # Normally I'd use overrideAttrs, but that wouldn't affect keyd-application-mapper
  keyd =
    let
      # TODO: I'm assuming that the first 10 characters is enough for it to be
      # unique.
      version = "2.5.0-${substring 0 10 pins.keyd.revision}";

      src = pins.keyd;

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
in
{
  inherit
    config-file-validator
    keyd
    ;
}
