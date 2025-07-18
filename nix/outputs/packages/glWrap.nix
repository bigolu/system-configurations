# Wrap GUIs with nix-gl-host so they work correctly on non-NixOS linux systems.
#
# This is an alternative, though it doesn't support nvidia.
# https://github.com/soupglasses/nix-system-graphics
#
# TODO: Issues:
# https://github.com/NixOS/nixpkgs/issues/62169
# https://github.com/NixOS/nixpkgs/issues/9415
#
# TODO: Maybe upstream this function to nix-gl-host.

{ nixpkgs, inputs, ... }:
nixpkgs.callPackage (
  {
    symlinkJoin,
    writeScriptBin,
    lib,
    nix-gl-host ? inputs.nix-gl-host.outputs,
    bash,
  }:
  package:
  let
    inherit (lib)
      getExe
      recursiveUpdate
      ;

    packageName = package.pname;
    packageExe = getExe package;
    nixglhostExe = getExe nix-gl-host;
    bashExe = getExe bash;

    # I reference dependencies directly to avoid polluting the PATH.
    wrappedExecutable = writeScriptBin packageName ''
      #!${bashExe}
      exec ${nixglhostExe} ${packageExe} "$@"
    '';

    wrappedPackage = symlinkJoin {
      pname = "${packageName}-with-nix-gl-host";
      inherit (package) version;
      paths = [
        wrappedExecutable
        package
      ];
    };
  in
  # Merge with the original package to retain attributes like meta, terminfo, etc.
  recursiveUpdate package wrappedPackage
) { }
