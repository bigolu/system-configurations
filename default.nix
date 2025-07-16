{
  # This shouldn't be overridden
  pins ? import ./nix/npins-wrapper.nix { inherit pkgs; },

  # In flake pure evaluation mode, `builtins.currentSystem` can't be accessed so
  # we'll take system as a parameter.
  system ? builtins.currentSystem,

  # Unlink other pins, we take in an already-imported nixpkgs instance since
  # evaluating nixpkgs takes a long time[1].
  #
  # [1]: https://zimbatm.com/notes/1000-instances-of-nixpkgs
  pkgs ? import pins.nixpkgs { inherit system; },

  # Overridable pins
  gomod2nix ? pins.gomod2nix,
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
      inherit (pkgs.lib)
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
      (outputs: outputs // { inherit context; })
    ];

  # TODO: I can't use `foo@` on the top-level function since it wouldn't include
  # arguments with a default value: https://github.com/NixOS/nix/issues/1461. I
  # could remove the defaults, but I want it to be used with callPackage.
  context = {
    inherit
      system
      pkgs
      outputs
      ;
    inherit (pkgs) lib;
    pins = pins // {
      home-manager = pins.home-manager // { outputs = import pins.home-manager {}; };
    };
    gomod2nix = pkgs.lib.makeScope pkgs.newScope (self: {
      gomod2nix = self.callPackage gomod2nix.outPath { };
      inherit (self.callPackage "${gomod2nix}/builder" { inherit (self) gomod2nix; })
        buildGoApplication
        mkGoEnv
        mkVendorEnv
        ;
    });

    private = {
      pkgs = import ./nix/private/packages context;
      utils = import ./nix/private/utils.nix context;
      # I keep a nixpkgs-stable channel, in addition to unstable, since there's a
      # higher chance that something builds on a stable channel.
      nixpkgs-stable = import pins.nixpkgs-stable { inherit system; };
    };
  };

  outputs = makeOutputs { inherit context; };
in
outputs
