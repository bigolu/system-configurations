{ inputs, utils }:
final: prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib)
    hasPrefix
    filterAttrs
    mapAttrs'
    removePrefix
    nameValuePair
    mapAttrs
    pipe
    composeManyExtensions
    ;
  inherit (utils) formatDate;

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
          hasRepositoryPrefix = hasPrefix repositoryPrefix;
        in
        filterAttrs (repositoryName: _ignored: hasRepositoryPrefix repositoryName) repositories;

      removePrefixFromRepositories =
        repositories:
        mapAttrs' (
          repositoryName: repositorySourceCode:
          let
            repositoryNameWithoutPrefix = removePrefix repositoryPrefix repositoryName;
          in
          nameValuePair repositoryNameWithoutPrefix repositorySourceCode
        ) repositories;

      buildPackagesFromRepositories =
        repositories:
        let
          buildPackage =
            repositoryName: repositorySourceCode:
            let
              date = formatDate repositorySourceCode.lastModifiedDate;
            in
            builder repositoryName repositorySourceCode date;
        in
        mapAttrs buildPackage repositories;
    in
    pipe inputs [
      filterRepositoriesForPrefix
      removePrefixFromRepositories
      buildPackagesFromRepositories
    ];
  composedOverlays =
    pipe
      [
        ./fish-plugins.nix
        ./vim-plugins.nix
      ]
      [
        (map (path: import path { inherit inputs utils makePluginPackages; }))
        composeManyExtensions
      ];
in
composedOverlays final prev
