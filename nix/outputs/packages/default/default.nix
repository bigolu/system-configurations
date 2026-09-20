{ pkgs, ... }:
pkgs.callPackage (
  {
    lib,
    makeWrapper,
    runCommand,
    nushell,
    git,
    direnv,
    bash,
    coreutils,
  }:
  let
    inherit (lib) makeBinPath;
    name = "init-config";
  in
  runCommand name
    {
      nativeBuildInputs = [ makeWrapper ];
      buildInputs = [ nushell ];
      meta.mainProgram = name;
    }
    ''
      mkdir --parents $out/bin
      cp ${./init-config.nu} $out/bin/${name}
      chmod +x $out/bin/${name}
      patchShebangs $out/bin/${name}
      wrapProgram $out/bin/${name} \
        --prefix PATH : ${
          makeBinPath [
            nushell
            git
            direnv
            # direnv plugins assume these are on the PATH
            bash
            coreutils
          ]
        }
    ''
) { }
