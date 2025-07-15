context@{ sources, lib, private, ... }:
final: prev:
let
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
  inherit (private.utils) toNixpkgsAttr;

  # repositoryPrefix: e.g. 'vim-plugin-'
  # builder: (repositoryName: repositorySourceCode: date: derivation)
  #
  # returns: A set with the form:
  # {<repository name with `repositoryPrefix` removed and nixpkgs' naming conventions applied> = derivation}
  makePluginPackages =
    repositoryPrefix: builder:
    let
      filterNamesForRepositoryPrefix =
        repositories:
        let
          hasRepositoryPrefix = hasPrefix repositoryPrefix;
        in
        filterAttrs (repositoryName: _ignored: hasRepositoryPrefix repositoryName) repositories;

      removePrefixFromRepositoryNames =
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
            name: source:
            builder name source source.revision;
        in
        mapAttrs buildPackage repositories;
    in
    pipe sources [
      filterNamesForRepositoryPrefix
      removePrefixFromRepositoryNames
      buildPackagesFromRepositories
      (mapAttrs' (name: nameValuePair (toNixpkgsAttr name)))
    ];
  composedOverlays =
    pipe
      [
        ./fish-plugins.nix
        ./vim-plugins.nix
      ]
      [
        (map (path: import path (context // {inherit makePluginPackages;})))
        composeManyExtensions
      ];
in
composedOverlays final prev
