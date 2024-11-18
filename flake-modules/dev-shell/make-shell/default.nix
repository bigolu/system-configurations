{ pkgs, self }:
{
  packages ? [ ],
  shellHook ? null,
  mergeWith ? [ ],
}:
let
  inherit (pkgs) lib;
  inherit (lib.trivial) pipe;
  inherit (lib.lists) unique concatLists optionals;
  inherit (lib.strings) concatStringsSep;

  concatListsAndDeduplicate =
    listOfLists:
    pipe listOfLists [
      concatLists
      unique
    ];

  mergedPackages =
    let
      packagesFromShellsToMergeWith = pipe mergeWith [
        (map (shell: shell._packages))
        concatLists
      ];
    in
    concatListsAndDeduplicate [
      packagesFromShellsToMergeWith
      packages
    ];

  mergedShellHooks =
    let
      registryShellHook = import ./registry-shell-hook.nix { inherit pkgs self; };

      shellHooksFromShellsToMergeWith = pipe mergeWith [
        (map (shell: shell._shellHooks))
        concatLists
      ];
    in
    concatListsAndDeduplicate [
      [ registryShellHook ]
      shellHooksFromShellsToMergeWith
    ]
    ++ optionals (shellHook != null) [ shellHook ];

  # There's work being done that would bring a lot of improvements to Nix shells:
  # https://github.com/NixOS/nixpkgs/pull/330822
  shell = pkgs.mkShellNoCC {
    packages = mergedPackages;
    shellHook = concatStringsSep "\n" mergedShellHooks;
  };
in
shell
// {
  _packages = mergedPackages;
  _shellHooks = mergedShellHooks;
}
