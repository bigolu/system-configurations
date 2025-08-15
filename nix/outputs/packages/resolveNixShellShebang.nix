{
  nixpkgs,
  inputs,
  utils,
  ...
}:
nixpkgs.callPackage (
  {
    pkgs,
    lib,
    mkShellBin ? inputs.nix-mk-shell-bin.outputs.lib.mkShellBin,
    writeShellScript,
  }:
  let
    inherit (lib)
      pipe
      pathIsDirectory
      splitString
      hasPrefix
      readFile
      filter
      concatMap
      findFirst
      removePrefix
      any
      escapeShellArgs
      isStorePath
      ;

    nixShellDirectivePrefix = "#! nix-shell";
    isNixShellDirective = hasPrefix nixShellDirectivePrefix;

    # Use the same `runCommand` as the nix CLI[1].
    #
    # [1]: https://github.com/NixOS/nix/blob/0b7f7e4b03ea162ad059e283dd6402f50d585d2d/src/nix/nix-build/nix-build.cc#L340
    nixCliRunCommand = pkgs.pkgs.runCommandCC or pkgs.pkgs.runCommand;

    resolveDirectory =
      let
        inherit (lib.filesystem) listFilesRecursive;
        inherit (utils) applyIf linkFarm;

        listRelativeFilesRecursive =
          directory:
          pipe directory [
            listFilesRecursive
            (map (path: removePrefix "${toString directory}/" (toString path)))
          ];

        hasNixShellDirective =
          file:
          pipe file [
            readFile
            (splitString "\n")
            (any isNixShellDirective)
          ];
      in
      directory:
      pipe directory [
        listRelativeFilesRecursive
        (map (file: {
          name = file;
          path = applyIf (hasNixShellDirective "${directory}/${file}") resolveFile "${directory}/${file}";
        }))
        (linkFarm "resolved-${baseNameOf directory}")
      ];

    resolveFile =
      let
        inherit (nixCliRunCommand "no-name" { } "") stdenv;

        getNixShellDirectives =
          file:
          pipe file [
            readFile
            (splitString "\n")
            (filter isNixShellDirective)
          ];

        getPackagesFromDirective =
          directive:
          lib.pipe directive [
            # A nix-shell directive that specifies packages will resemble:
            #   #! nix-shell --packages/-p package1 package2
            #
            # So this match will match everything after the package flag i.e.
            # 'package1 package2'.
            (lib.match ''^${nixShellDirectivePrefix} (--packages|-p) (.*)'')
            (matches: if matches != null then lib.elemAt matches 1 else null)
            (packageString: if packageString != null then lib.splitString " " packageString else [ ])
            (map (packageName: pkgs.${packageName}))
          ];

        # TODO: This doesn't handle expressions yet, only attribute names.
        getPackages =
          file:
          pipe file [
            getNixShellDirectives
            (concatMap getPackagesFromDirective)
          ];

        getInterpreter =
          file:
          let
            interpreterDirective = "${nixShellDirectivePrefix} -i ";
          in
          pipe file [
            readFile
            (splitString "\n")
            (findFirst (hasPrefix interpreterDirective) null)
            (removePrefix interpreterDirective)
          ];
      in
      file:
      let
        packages = getPackages file;
        interpreter = getInterpreter file;
        # This is how nix creates the environment for a shebang script[1], except we
        # use `nativeBuildInputs` instead of `buildInputs` since nix-mk-shell-bin
        # provides the _build_ environment for the input derivation.
        #
        # [1]: https://github.com/NixOS/nix/blob/0b7f7e4b03ea162ad059e283dd6402f50d585d2d/src/nix/nix-build/nix-build.cc#L340
        environmentDrv = nixCliRunCommand "${baseNameOf file}-shebang-env" {
          nativeBuildInputs = packages;
        } "";
        inherit
          (mkShellBin {
            inherit nixpkgs;
            drv = environmentDrv;
          })
          envScript
          ;
      in
      (writeShellScript "resolved-${baseNameOf file}" ''
        source ${envScript}
        unset TMP TMPDIR TEMP TEMPDIR
        exec ${
          escapeShellArgs [
            interpreter
            # Files should have their own store path so only changed files have to be
            # re-resolved.
            (if isStorePath file then file else builtins.path { path = file; })
          ]
        } "$@"
      '')
      // {
        packages = packages ++ [ stdenv ];
      };
  in
  path: if pathIsDirectory path then resolveDirectory path else resolveFile path
) { }
