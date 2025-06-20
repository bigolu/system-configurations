# Wrap GUIs with nix-gl-host so they work correctly on non-NixOS linux systems.
#
# TODO: This may be a better solution if I weren't using nvidia:
# https://github.com/soupglasses/nix-system-graphics
#
# TODO: Nix is trying to fix this issue:
# https://github.com/NixOS/nixpkgs/issues/62169
# https://github.com/NixOS/nixpkgs/issues/9415

_: final: prev:
let
  inherit (prev) symlinkJoin writeScriptBin;
  inherit (prev.stdenv) isLinux;
  inherit (prev.lib)
    optionalAttrs
    pipe
    getExe
    mergeAttrsList
    recursiveUpdate
    ;

  wrap =
    packageName:
    let
      package = prev.${packageName};
      packageExecutable = getExe package;
      nixglhost = getExe final.nix-gl-host;
      bash = getExe final.bash;

      # I reference dependencies directly to avoid polluting the PATH.
      wrappedExecutable = writeScriptBin packageName ''
        #!${bash}
        exec ${nixglhost} ${packageExecutable} "$@"
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
    recursiveUpdate package wrappedPackage;

  wrapPackages =
    packageNames:
    pipe packageNames [
      (map (packageName: {
        ${packageName} = wrap packageName;
      }))
      mergeAttrsList
    ];
in
optionalAttrs isLinux (wrapPackages [ ])
