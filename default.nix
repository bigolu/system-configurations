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

  gomod2nix ? pins.gomod2nix,
  gitignore ? pins.gitignore,
}:
let
  makeOutputs =
    {
      outputRoot ? ./nix/outputs,
      context,
    }:
    let
      inherit (builtins)
        foldl'
        filter
        pathExists
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
          relativePath = removePrefix "${toString outputRoot}/" (toString file);
          parts = splitString "/" relativePath;
          basename = last parts;
          keys = (init parts) ++ optionals (basename != "default.nix") [ (removeSuffix ".nix" basename) ];
        in
        setAttrByPath keys (import file context);

      enable =
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
      (filter enable)
      (map makeOutputsForFile)
      (foldl' recursiveUpdate { })
      (outputs: outputs // { inherit context; })
    ];

  # TODO: I can't use `foo@` on the top-level function since it wouldn't include
  # arguments with a default value: https://github.com/NixOS/nix/issues/1461. I could
  # remove the defaults, but I want the CLI to be able to automatically call it.
  context = {
    inherit
      system
      pkgs
      outputs
      ;
    inherit (pkgs) lib;
    # Incorporate any potential pin overrides and import their outputs.
    pins = pins // {
      gitignore = gitignore // {
        outputs = import gitignore { inherit (pkgs) lib; };
      };
      home-manager = pins.home-manager // {
        outputs = (import pins.home-manager { inherit pkgs; }) // {
          # TODO: This should be included in the default.nix
          nix-darwin = "${pins.home-manager}/nix-darwin";
        };
      };
      nix-gl-host = pins.nix-gl-host // {
        outputs = import pins.nix-gl-host { inherit pkgs; };
      };
      # TODO: Use the npins in nixpkgs once it has this commit:
      # https://github.com/andir/npins/commit/afa9fe50cb0bff9ba7e9f7796892f71722b2180d
      npins = pins.npins // {
        outputs = import pins.npins { inherit pkgs; };
      };
      gomod2nix = gomod2nix // {
        outputs = pkgs.lib.makeScope pkgs.newScope (self: {
          gomod2nix = self.callPackage gomod2nix.outPath { };
          inherit (self.callPackage "${gomod2nix}/builder" { inherit (self) gomod2nix; })
            buildGoApplication
            mkGoEnv
            mkVendorEnv
            ;
        });
      };
      nix-darwin = pins.nix-darwin // {
        outputs = (import pins.nix-darwin { inherit pkgs; }) // {
          # TODO: This is only defined in flake.nix so I had to copy it. I should open an issue.
          darwinSystem =
            args@{ modules, ... }:
            (import "${pins.nix-darwin}/eval-config.nix") (
              {
                inherit (pkgs) lib;
              }
              // pkgs.lib.optionalAttrs (args ? pkgs) { inherit (args.pkgs) lib; }
              // builtins.removeAttrs args [
                "system"
                "pkgs"
                "inputs"
              ]
              // {
                modules =
                  modules
                  ++ pkgs.lib.optional (args ? pkgs) (
                    { lib, ... }:
                    {
                      _module.args.pkgs = lib.mkForce args.pkgs;
                    }
                  )
                  # Backwards compatibility shim; TODO: warn?
                  ++ pkgs.lib.optional (args ? system) (
                    { lib, ... }:
                    {
                      nixpkgs.system = lib.mkDefault args.system;
                    }
                  )
                  # Backwards compatibility shim; TODO: warn?
                  ++ pkgs.lib.optional (args ? inputs) {
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
    utils = {
      # For performance, this shouldn't be called often[1] so we'll save a reference.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      gitFilter =
        src:
        pkgs.lib.cleanSourceWith {
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
