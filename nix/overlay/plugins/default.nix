{ inputs, utils }:
final: prev:
let
  inherit (inputs.nixpkgs) lib;

  # repositoryPrefix:
  # builder: (repositoryName: repositorySourceCode: date: derivation)
  #
  # returns: A set with the form {<repo name with `repositoryPrefix` removed> = derivation}
  makePluginPackages =
    repositoryPrefix: builder:
    let
      filterRepositoriesForPrefix =
        repositories:
        let
          hasRepositoryPrefix = lib.hasPrefix repositoryPrefix;
        in
        lib.attrsets.filterAttrs (
          repositoryName: _ignored: hasRepositoryPrefix repositoryName
        ) repositories;

      removePrefixFromRepositories =
        repositories:
        lib.mapAttrs' (
          repositoryName: repositorySourceCode:
          let
            repositoryNameWithoutPrefix = lib.strings.removePrefix repositoryPrefix repositoryName;
          in
          lib.nameValuePair repositoryNameWithoutPrefix repositorySourceCode
        ) repositories;

      buildPackagesFromRepositories =
        repositories:
        let
          buildPackage =
            repositoryName: repositorySourceCode:
            let
              date = utils.formatDate repositorySourceCode.lastModifiedDate;
            in
            builder repositoryName repositorySourceCode date;
        in
        lib.mapAttrs buildPackage repositories;
    in
    lib.trivial.pipe inputs [
      filterRepositoriesForPrefix
      removePrefixFromRepositories
      buildPackagesFromRepositories
    ];
  composedOverlays =
    lib.trivial.pipe
      [
        ./fish-plugins.nix
        ./vim-plugins.nix
      ]
      [
        (map (path: import path { inherit inputs utils makePluginPackages; }))
        lib.composeManyExtensions
      ];
in
composedOverlays final prev