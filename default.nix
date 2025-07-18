{
  # This shouldn't be overridden, it's only here because of a mutual dependency with
  # nixpkgs.
  pins ? import ./nix/npins-wrapper.nix { inherit nixpkgs; },

  # In flake pure evaluation mode, `builtins.currentSystem` can't be accessed so
  # we'll take system as a parameter.
  system ? builtins.currentSystem,

  # It's recommended to override this pin for two reasons[1]:
  #   - The nixpkgs repo is about 200 MB so multiple checkouts would take up a lot
  #     of space.
  #   - It takes about a second to evaluate nixpkgs i.e. `import <nixpkgs> {}`.
  #     For this reason, unlike other pins, we take an already-evaluated nixpkgs
  #     instead of the source code.
  #
  # For more info: https://zimbatm.com/notes/1000-instances-of-nixpkgs
  nixpkgs ? import pins.nixpkgs { inherit system; },

  gomod2nix ? pins.gomod2nix,
  gitignore ? pins.gitignore,
}:
let
  makeOutputs =
    {
      outputRoot,
      context,
    }:
    let
      inherit (builtins)
        foldl'
        filter
        pathExists
        baseNameOf
        ;
      inherit (nixpkgs.lib)
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
          relativePath = removePrefix "${toString outputRoot}/" (toString file);
          parts = splitString "/" relativePath;
          basename = last parts;
          keys = (init parts) ++ optionals (basename != "default.nix") [ (removeSuffix ".nix" basename) ];
        in
        setAttrByPath keys (import file context);

      shouldMakeOutputs =
        file:
        let
          hasAncestorDefaultNix =
            dir:
            pathExists (dir + /default.nix)
            || (if dir == outputRoot then false else hasAncestorDefaultNix (dirOf dir));
          dir = dirOf file;
        in
        if (baseNameOf file) == "default.nix" then
          dir == outputRoot || !(hasAncestorDefaultNix (dirOf dir))
        else
          !hasAncestorDefaultNix dir;
    in
    pipe outputRoot [
      (fileset.fileFilter (file: file.hasExt "nix"))
      fileset.toList
      (filter shouldMakeOutputs)
      (map makeOutputsForFile)
      (foldl' recursiveUpdate { })
      (outputs: outputs // { inherit context; })
    ];

  # TODO: I can't use `foo@` on the top-level function since it wouldn't include
  # arguments with a default value: https://github.com/NixOS/nix/issues/1461.
  context = {
    inherit
      system
      outputs
      ;

    # These are commonly used so lets make them easier to access by exposing them at
    # the top level.
    inherit nixpkgs;
    inherit (nixpkgs) lib;

    utils = import ./nix/utils context;
    packages = import ./nix/packages context;

    # Incorporate any potential pin overrides and import their outputs.
    pins = pins // {
      gitignore = gitignore // {
        outputs = import gitignore { inherit (nixpkgs) lib; };
      };
      home-manager = pins.home-manager // {
        outputs = (import pins.home-manager { pkgs = nixpkgs; }) // {
          # TODO: This should be included in the default.nix
          nix-darwin = "${pins.home-manager}/nix-darwin";
        };
      };
      nix-gl-host = pins.nix-gl-host // {
        outputs = import pins.nix-gl-host { pkgs = nixpkgs; };
      };
      # TODO: Use the npins in nixpkgs once it has this commit:
      # https://github.com/andir/npins/commit/afa9fe50cb0bff9ba7e9f7796892f71722b2180d
      npins = pins.npins // {
        outputs = import pins.npins { pkgs = nixpkgs; };
      };
      gomod2nix = gomod2nix // {
        outputs = nixpkgs.lib.makeScope nixpkgs.newScope (self: {
          gomod2nix = self.callPackage gomod2nix.outPath { };
          inherit (self.callPackage "${gomod2nix}/builder" { inherit (self) gomod2nix; })
            buildGoApplication
            mkGoEnv
            mkVendorEnv
            ;
        });
      };
      nixpkgs = pins.nixpkgs // {
        outputs = nixpkgs;
      };
      # I keep a nixpkgs-stable channel, in addition to unstable, since there's a
      # higher chance that something builds on a stable channel.
      nixpkgs-stable = pins.nixpkgs-stable // {
        outputs = import pins.nixpkgs-stable { inherit system; };
      };
      nix-darwin = pins.nix-darwin // {
        outputs = (import pins.nix-darwin { pkgs = nixpkgs; }) // {
          # TODO: This is only defined in flake.nix so I had to copy it. I should
          # open an issue.
          darwinSystem =
            args@{ modules, ... }:
            (import "${pins.nix-darwin}/eval-config.nix") (
              {
                inherit (nixpkgs) lib;
              }
              // nixpkgs.lib.optionalAttrs (args ? pkgs) { inherit (args.pkgs) lib; }
              // builtins.removeAttrs args [
                "system"
                "pkgs"
                "inputs"
              ]
              // {
                modules =
                  modules
                  ++ nixpkgs.lib.optional (args ? pkgs) (
                    { lib, ... }:
                    {
                      _module.args.pkgs = lib.mkForce args.pkgs;
                    }
                  )
                  # Backwards compatibility shim; TODO: warn?
                  ++ nixpkgs.lib.optional (args ? system) (
                    { lib, ... }:
                    {
                      nixpkgs.system = lib.mkDefault args.system;
                    }
                  )
                  # Backwards compatibility shim; TODO: warn?
                  ++ nixpkgs.lib.optional (args ? inputs) {
                    _module.args.inputs = args.inputs;
                  }
                  ++ [
                    (
                      { lib, ... }:
                      {
                        nixpkgs.source = lib.mkDefault pins.nixpkgs;
                        nixpkgs.flake.source = lib.mkDefault pins.nixpkgs.outPath;

                        system = {
                          checks.verifyNixPath = lib.mkDefault false;
                          darwinVersionSuffix = ".dirty";
                          darwinRevision =
                            let
                              rev = null;
                            in
                            lib.mkIf (rev != null) rev;
                        };
                      }
                    )
                  ];
              }
            );
        };
      };
    };
  };

  outputs = makeOutputs {
    inherit context;
    outputRoot = ./nix/outputs;
  };
in
outputs
