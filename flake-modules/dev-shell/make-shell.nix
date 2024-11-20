{ pkgs, root }:
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
  inherit (lib) fileset;

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
      essentialHooks =
        let
          # nixd needs this[1]. I also need this for my nix-shell shebangs.
          #
          # TODO: Maybe I should mention what I'm doing to nixd since this allows
          # custom packages that you make to get picked up by nixd as well.
          #
          # [1]: https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#default-configuration--who-needs-configuration
          nixPathShellHook =
            let
              files = [
                "flake.nix"
                "flake.lock"
                "default.nix"
                "nixpkgs.nix"
                "flake-modules"
              ];

              filesAsFileset = fileset.unions (map (file: root + "/${file}") files);

              packages = fileset.toSource {
                inherit root;
                fileset = filesAsFileset;
              };
            in
            ''
              # You may be wondering why I'm not just using $PWD instead of a
              # fileset. cached-nix-shell traces the files accessed during the
              # nix-shell invocation so it knows when to invalidate the cache. When I
              # use PWD, a lot of files unrelated to nix, like <REPO>/.git/index,
              # become part of the trace, resulting in a lot of unnecessary cache
              # invalidations.
              export NIX_PATH="nixpkgs=${packages}/nixpkgs.nix''${NIX_PATH+:}''${NIX_PATH:-}"
            '';
        in
        [ nixPathShellHook ];

      shellHooksFromShellsToMergeWith = pipe mergeWith [
        (map (shell: shell._shellHooks))
        concatLists
      ];
    in
    concatListsAndDeduplicate [
      essentialHooks
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
