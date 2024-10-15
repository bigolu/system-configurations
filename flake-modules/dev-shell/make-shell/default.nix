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
      baseShellHooks = import ./base-shell-hooks.nix { inherit pkgs self; };

      shellHooksFromShellsToMergeWith = pipe mergeWith [
        (map (shell: shell._shellHooks))
        concatLists
      ];
    in
    concatListsAndDeduplicate [
      baseShellHooks
      shellHooksFromShellsToMergeWith
    ]
    ++ optionals (shellHook != null) [ shellHook ];

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
