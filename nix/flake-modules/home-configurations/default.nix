{
  inputs,
  lib,
  utils,
  withSystem,
  ...
}:
let
  inherit (utils.homeManager) moduleRoot baseModule;
  inherit (builtins) attrValues mapAttrs listToAttrs;
  inherit (lib)
    pipe
    mergeAttrs
    nameValuePair
    mergeAttrsList
    ;

  makeEmptyPackage =
    pkgs: packageName:
    pkgs.runCommand "${packageName}-empty" { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';

  # These variables contain the path to the locale archive in
  # pkgs.glibcLocales. There is no option to prevent Home Manager from making
  # these environment variables and overriding glibcLocales in an overlay would
  # cause too many rebuild so instead I overwrite the environment variables.
  # Now glibcLocales won't be a dependency.
  emptySessionVariables = lib.mkForce {
    LOCALE_ARCHIVE_2_27 = "";
    LOCALE_ARCHIVE_2_11 = "";
  };

  # When I called nix-tree with the portable home, I got a warning that calling
  # lib.getExe on a package that doesn't have a meta.mainProgram is deprecated. The
  # package that was lib.getExe was called with is nix.
  portableOverlay =
    final: _prev:
    pipe
      [
        "comma"
        "moreutils"
        "timg"
        "ripgrep-all"
        "lesspipe"
        "wordnet"
        "diffoscopeMinimal"
        "gitMinimal"
        "difftastic"
        "nix"
      ]
      [
        (map (packageName: nameValuePair packageName (makeEmptyPackage final packageName)))
        listToAttrs
      ];

  portableModule =
    { lib, pkgs, ... }:
    {
      # I want a self contained executable so I can't have symlinks that point
      # outside the Nix store.
      repository.fileSettings.editableInstall = lib.mkForce false;

      programs = {
        home-manager.enable = lib.mkForce false;
        nix-index = {
          enable = false;
          symlinkToCacheHome = false;
        };
      };

      home = {
        sessionVariables = lib.attrsets.optionalAttrs pkgs.stdenv.isLinux emptySessionVariables;

        file.".hammerspoon/Spoons/EmmyLua.spoon" = lib.mkForce {
          source = makeEmptyPackage pkgs "stub-spoon";
          recursive = false;
        };

        # Since I'm running Home Manager in "submodule mode", I have to set these or
        # else it won't build.
        username = "biggs";
        homeDirectory = "/no/home/directory";
      };

      systemd.user = {
        # This removes the dependency on `sd-switch`.
        startServices = lib.mkForce "suggest";
        sessionVariables = lib.attrsets.optionalAttrs pkgs.stdenv.isLinux emptySessionVariables;
      };

      xdg = {
        mime.enable = lib.mkForce false;

        dataFile = {
          "fzf/fzf-history.txt".source = pkgs.writeText "fzf-history.txt" "";

          "nvim/site/parser" = lib.mkForce {
            source = makeEmptyPackage pkgs "parsers";
          };
        };
      };

      # to remove the flake registry
      nix.enable = false;
    };

  makeOutputsForSpec =
    spec@{
      systems,
      overlay ? null,
      configName,
      modules,
      isGui ? true,
      username ? "biggs",
      isHomeManagerRunningAsASubmodule ? false,
    }:
    let
      getOutputNameForSystem =
        system: if (builtins.length systems) == 1 then configName else "${configName}-${system}";

      makeConfigForSystem =
        system:
        withSystem system (
          { pkgs, ... }:
          let
            homePrefix = if pkgs.stdenv.isLinux then "/home" else "/Users";
            homeDirectory =
              if builtins.hasAttr "homeDirectory" spec then spec.homeDirectory else "${homePrefix}/${username}";
            repositoryDirectory =
              if builtins.hasAttr "repositoryDirectory" spec then
                spec.repositoryDirectory
              else
                "${homeDirectory}/code/system-configurations";
            # SYNC: SPECIAL-ARGS
            extraSpecialArgs = {
              inherit
                configName
                homeDirectory
                isGui
                isHomeManagerRunningAsASubmodule
                repositoryDirectory
                username
                utils
                inputs
                ;
            };
          in
          inputs.home-manager.lib.homeManagerConfiguration {
            modules = modules ++ [ baseModule ];
            inherit extraSpecialArgs;
            pkgs = if overlay == null then pkgs else pkgs.extend overlay;
          }
        );
    in
    pipe systems [
      (map (system: nameValuePair (getOutputNameForSystem system) (makeConfigForSystem system)))
      builtins.listToAttrs
    ];

  makeOutputs = configSpecs: {
    # The 'flake' and 'homeConfigurations' keys need to be static to avoid infinite
    # recursion
    flake.homeConfigurations = pipe configSpecs [
      (mapAttrs (configName: mergeAttrs { inherit configName; }))
      attrValues
      (map makeOutputsForSpec)
      mergeAttrsList
    ];
  };

in
makeOutputs {
  linux = {
    systems = with inputs.flake-utils.lib.system; [ x86_64-linux ];
    modules = [
      "${moduleRoot}/profile/application-development.nix"
      "${moduleRoot}/profile/system-administration.nix"
      "${moduleRoot}/profile/personal.nix"
    ];
  };

  portable-home = {
    systems = with inputs.flake-utils.lib.system; [
      x86_64-linux
      x86_64-darwin
    ];
    modules = [
      "${moduleRoot}/profile/system-administration.nix"
      portableModule
    ];
    overlay = portableOverlay;
    isGui = false;
    isHomeManagerRunningAsASubmodule = true;
  };
}
