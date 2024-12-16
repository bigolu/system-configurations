{
  inputs,
  lib,
  utils,
  withSystem,
  ...
}:
let
  inherit (utils.homeManager) moduleRoot baseModule;

  makeEmptyPackage =
    pkgs: packageName:
    pkgs.runCommand packageName { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';

  # When I called nix-tree with the portable home, I got a warning that calling
  # lib.getExe on a package that doesn't have a meta.mainProgram is deprecated. The
  # package that was lib.getExe was called with is nix.
  portableOverlay =
    final: _prev:
    let
      makeNameValuePair = packageName: {
        name = packageName;
        value = makeEmptyPackage final packageName;
      };
      nameValuePairs = map makeNameValuePair [
        "comma"
        "moreutils"
        "ast-grep"
        "timg"
        "ripgrep-all"
        "lesspipe"
        "wordnet"
        "diffoscopeMinimal"
        "gitMinimal"
        "difftastic"
        "nix"
      ];
    in
    builtins.listToAttrs nameValuePairs;

  portableModule =
    { lib, pkgs, ... }:
    {
      # I want a self contained executable so I can't have symlinks that point
      # outside the Nix store.
      repository.symlink.makeCopiesInstead = true;

      programs.nix-index = {
        enable = false;
        symlinkToCacheHome = false;
      };

      programs.home-manager.enable = lib.mkForce false;

      # This removes the dependency on `sd-switch`.
      systemd.user.startServices = lib.mkForce "suggest";
      home = {
        # These variables contain the path to the locale archive in
        # pkgs.glibcLocales. There is no option to prevent Home Manager from making
        # these environment variables and overriding glibcLocales in an overlay would
        # cause too many rebuild so instead I overwrite the environment variables.
        # Now, glibcLocales won't be a dependency.
        sessionVariables = lib.attrsets.optionalAttrs pkgs.stdenv.isLinux (
          lib.mkForce {
            LOCALE_ARCHIVE_2_27 = "";
            LOCALE_ARCHIVE_2_11 = "";
          }
        );

        file.".hammerspoon/Spoons/EmmyLua.spoon" = lib.mkForce {
          source = makeEmptyPackage pkgs "stub-spoon";
          recursive = false;
        };

        # Since I'm running Home Manager in "submodule mode", I have to set these or
        # else it won't build.
        username = "guest";
        homeDirectory = "/no/home/directory";
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

  makeHomeConfigurations =
    args@{
      systems,
      overlay ? null,
      configName,
      modules,
      isGui ? true,
      username ? "biggs",
      isHomeManagerRunningAsASubmodule ? false,
    }:
    builtins.listToAttrs (
      map (
        system:
        withSystem system (
          { pkgs, ... }:
          let
            homePrefix = if pkgs.stdenv.isLinux then "/home" else "/Users";
            homeDirectory =
              if builtins.hasAttr "homeDirectory" args then args.homeDirectory else "${homePrefix}/${username}";
            repositoryDirectory =
              if builtins.hasAttr "repositoryDirectory" args then
                args.repositoryDirectory
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
              inherit (utils) projectRoot;
            };

          in
          {
            name = if (builtins.length systems) == 1 then configName else "${configName}-${system}";
            value = inputs.home-manager.lib.homeManagerConfiguration {
              modules = modules ++ [ baseModule ];
              inherit extraSpecialArgs;
              pkgs = if overlay == null then pkgs else pkgs.extend overlay;
            };
          }
        )
      ) systems
    );

  makeOutputs =
    configSpecs:
    let
      names = builtins.attrNames configSpecs;
      configsByName = lib.foldl (acc: next: acc // next) { } (
        map (name: makeHomeConfigurations (configSpecs.${name} // { configName = name; })) names
      );
    in
    {
      flake.homeConfigurations = configsByName;
    };
in
makeOutputs {
  desktop = {
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
    overlay = portableOverlay;
    isGui = false;
    isHomeManagerRunningAsASubmodule = true;
    modules = [
      "${moduleRoot}/profile/system-administration.nix"
      portableModule
    ];
  };
}
