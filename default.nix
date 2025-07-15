{
  sources ? import ./nix/npins-wrapper.nix { inherit pkgs; },
  # In flake pure evaluation mode, `builtins.currentSystem` can't be accessed so we'll
  # take system as a parameter.
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs { inherit system; },
  lib ? pkgs.lib,
}:
let
  makeOutputs =
    {
      directory ? ./nix/outputs,
      context,
    }:
    let
      inherit (builtins)
        foldl'
        filter
        pathExists
        dirOf
        baseNameOf
        ;
      inherit (lib)
        pipe
        removePrefix
        fileset
        splitString
        recursiveUpdate
        setAttrByPath
        init
        last
        optionals
        removeSuffix
        ;

      makeOutputsForFile =
        file:
        let
          relativePath = removePrefix "${toString directory}/" (toString file);
          parts = splitString "/" relativePath;
          basename = last parts;
          keys = (init parts) ++ optionals (basename != "default.nix") [ (removeSuffix ".nix" basename) ];
        in
        setAttrByPath keys (import file context);
    in
    pipe directory [
      (fileset.fileFilter (file: file.hasExt "nix"))
      fileset.toList
      # If there's a default.nix in a directory, ignore all other .nix files.
      # TODO: I have to look up recursively for default.nix, stop at output dir.
      (filter (file: ((baseNameOf file) == "default.nix") || (!pathExists ((dirOf file) + /default.nix))))
      (map makeOutputsForFile)
      (foldl' recursiveUpdate { })
      (outputs: outputs // { debug = context; })
    ];

  # TODO: I can't use `foo@` on the top-level function since it wouldn't include
  # arguments with a default value: https://github.com/NixOS/nix/issues/1461. I
  # could remove the defaults, but I want it to be used with callPackage.
  context = {
    inherit
      system
      sources
      pkgs
      lib
      outputs
      ;
    private = {
      pkgs = import ./nix/private/packages context;
      utils = import ./nix/private/utils.nix context;
      nixpkgs-stable = import sources.nixpkgs-stable { inherit system; };
    };
  };

  outputs = makeOutputs { inherit context; };
in
outputs
