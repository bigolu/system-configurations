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
    runCommand,
    writeShellScript,
  }:
  path:
  let
    inherit (lib)
      pipe
      pathIsDirectory
      splitString
      unique
      hasPrefix
      readFile
      match
      filter
      elemAt
      concatMap
      findFirst
      removePrefix
      any
      concatStrings
      escapeShellArg
      escapeShellArgs
      isStorePath
      ;
    inherit (lib.filesystem) listFilesRecursive;
    inherit (utils) applyIf;

    nixShellDirectivePrefix = "#! nix-shell";

    isNixShellDirective = hasPrefix nixShellDirectivePrefix;

    hasNixShellDirective =
      file:
      pipe file [
        readFile
        (splitString "\n")
        (any isNixShellDirective)
      ];

    extractNixShellDirectives =
      file:
      pipe file [
        readFile
        (splitString "\n")
        (filter isNixShellDirective)
      ];

    # TODO: This doesn't handle expressions yet, only attribute names.
    extractPackages =
      nixShellDirective:
      pipe nixShellDirective [
        # A nix-shell directive that specifies packages will resemble:
        #   #! nix-shell --packages/-p package1 package2
        #
        # So this match will match everything after the package flag i.e.
        # 'package1 package2'.
        (match ''^${nixShellDirectivePrefix} (--packages|-p) (.*)'')
        (matches: if matches != null then elemAt matches 1 else null)
        (packageString: if packageString != null then splitString " " packageString else [ ])
        unique
        (map (packageName: pkgs.${packageName}))
      ];

    extractInterpreter =
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

    listRelativeFilesRecursive =
      directory:
      pipe directory [
        listFilesRecursive
        (map (path: removePrefix "${toString directory}/" (toString path)))
      ];

    # There's a `linkFarm` in `lib`, but we can't use it since it coerces the entries
    # to a set and the keys in that set, i.e. the destination for each link, may have
    # string context which nix does not allow[1]. They may have context if the input
    # to `resolveNixShebang` is a directory from the nix store.
    #
    # [1]: https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226/4
    linkFarm =
      name: entries:
      let
        linkCommands = map (
          { name, path }:
          ''
            mkdir -p -- "$(dirname -- ${escapeShellArg "${name}"})"
            ln -s -- ${escapeShellArg "${path}"} ${escapeShellArg "${name}"}
          ''
        ) entries;
      in
      runCommand name { } ''
        mkdir -p $out
        cd $out
        ${concatStrings linkCommands}
      '';

    resolveDirectory =
      directory:
      pipe directory [
        listRelativeFilesRecursive
        (map (file: {
          name = file;
          path = applyIf (hasNixShellDirective "${directory}/${file}") resolveFile "${directory}/${file}";
        }))
        (linkFarm "resolved-${baseNameOf directory}")
      ];

    inherit ((pkgs.pkgs.runCommandCC or pkgs.pkgs.runCommand) "no-name" { } "") stdenv;

    resolveFile =
      file:
      let
        packages = pipe file [
          extractNixShellDirectives
          (concatMap extractPackages)
        ];
        interpreter = extractInterpreter file;
        # This is how nix creates the environment for a shebang script[1], except we
        # use `nativeBuildInputs` instead of `buildInputs` since nix-mk-shell-bin
        # provides the _build_ environment for the input derivation.
        #
        # [1]: https://github.com/NixOS/nix/blob/0b7f7e4b03ea162ad059e283dd6402f50d585d2d/src/nix/nix-build/nix-build.cc#L340
        drv = (pkgs.pkgs.runCommandCC or pkgs.pkgs.runCommand) "${baseNameOf file}-shebang-env" {
          nativeBuildInputs = packages;
        } "";
        inherit (mkShellBin { inherit drv nixpkgs; }) envScript;
      in
      (writeShellScript "patched-${baseNameOf file}" ''
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
  if pathIsDirectory path then resolveDirectory path else resolveFile path
) { }
