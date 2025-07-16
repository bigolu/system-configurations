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
  gitignore ? pins.gitignore,
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
        optionalAttrs
        ;

      makeOutputsForFile =
        file:
        let
          relativePath = removePrefix "${toString directory}/" (toString file);
          parts = splitString "/" relativePath;
          basename = last parts;
          keys = (init parts) ++ optionals (basename != "default.nix") [ (removeSuffix ".nix" basename) ];
          output = import file context;
        in
        optionalAttrs (output != null) (setAttrByPath keys output);
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
      gitignore = gitignore // { outputs = import gitignore { inherit (pkgs) lib; }; };
      home-manager = pins.home-manager // { outputs = (import pins.home-manager { inherit pkgs; }) // {
        # TODO: This should be included in the default.nix
        nix-darwin = "${pins.home-manager}/nix-darwin";
      }; };
      nix-darwin = pins.nix-darwin // { outputs = (import pins.nix-darwin { inherit pkgs; }) // {
        # TODO: This is only defined in flake.nix so I had to copy it. I should open an issue.
        darwinSystem = args@{ modules, ... }: (import "${pins.nix-darwin}/eval-config.nix") (
          { inherit (pkgs) lib; }
          // pkgs.lib.optionalAttrs (args ? pkgs) { inherit (args.pkgs) lib; }
          // builtins.removeAttrs args [ "system" "pkgs" "inputs" ]
          // {
            modules = modules
              ++ pkgs.lib.optional (args ? pkgs) ({ lib, ... }: {
                _module.args.pkgs = lib.mkForce args.pkgs;
              })
              # Backwards compatibility shim; TODO: warn?
              ++ pkgs.lib.optional (args ? system) ({ lib, ... }: {
                nixpkgs.system = lib.mkDefault args.system;
              })
              # Backwards compatibility shim; TODO: warn?
              ++ pkgs.lib.optional (args ? inputs) {
                _module.args.inputs = args.inputs;
              }
              ++ [ ({ lib, ... }: {
                nixpkgs.source = lib.mkDefault pins.nixpkgs;
                nixpkgs.flake.source = lib.mkDefault pins.nixpkgs.outPath;

                system = {
                  checks.verifyNixPath = lib.mkDefault false;
                  darwinVersionSuffix = ".dirty";
                  darwinRevision = let
                    rev = null;
                  in
                    lib.mkIf (rev != null) rev;
                };
              }) ];
            });
        }; };
    };
    gomod2nix = pkgs.lib.makeScope pkgs.newScope (self: {
      gomod2nix = self.callPackage gomod2nix.outPath { };
      inherit (self.callPackage "${gomod2nix}/builder" { inherit (self) gomod2nix; })
        buildGoApplication
        mkGoEnv
        mkVendorEnv
        ;
    });
    utils = {
      # For performance, this shouldn't be called often[1] so we'll save a reference.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      gitFilter = src: pkgs.lib.cleanSourceWith {
        filter = context.pins.gitignore.outputs.gitignoreFilterWith { basePath = ./.; };
        inherit src;
        name = "source";
      };
    };
    private = {
      pkgs = import ./nix/private/packages context;
      utils = import ./nix/private/utils context;
      # I keep a nixpkgs-stable channel, in addition to unstable, since there's a
      # higher chance that something builds on a stable channel.
      nixpkgs-stable = import pins.nixpkgs-stable { inherit system; };
    };
  };

  outputs = makeOutputs { inherit context; };
in
outputs
