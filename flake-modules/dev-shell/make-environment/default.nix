{ pkgs, self }:
{
  packages ? [ ],
  shellHooks ? [ ],
  environments ? [ ],
}:
let
  inherit (pkgs) lib;
  inherit (lib.trivial) pipe;
  inherit (lib.lists) unique concatLists;
  inherit (lib.strings) concatStringsSep;

  concatListsAndDeduplicate =
    listOfLists:
    pipe listOfLists [
      concatLists
      unique
    ];

  mergedPackages =
    let
      packagesFromEnvironments = pipe environments [
        (map (env: env._packages))
        concatLists
      ];
    in
    concatListsAndDeduplicate [
      packagesFromEnvironments
      packages
    ];

  mergedShellHooks =
    let
      baseShellHooks = import ./base-shell-hooks.nix { inherit pkgs self; };

      shellHooksFromEnvironments = pipe environments [
        (map (env: env._shellHooks))
        concatLists
      ];
    in
    concatListsAndDeduplicate [
      baseShellHooks
      shellHooksFromEnvironments
      shellHooks
    ];

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
