{
  self,
  inputs,
  pkgs,
  system,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  # When I called nix-tree with the portable home, I got a warning that calling
  # lib.getExe on a package that doesn't have a meta.mainProgram is deprecated. The
  # package that was lib.getExe was called with is nix.
  makeEmptyPackage =
    packageName: pkgs.runCommand packageName { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';
  portableOverlay =
    _final: _prev:
    let
      makeNameValuePair = packageName: {
        name = packageName;
        value = makeEmptyPackage packageName;
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

  portablePkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      self.lib.overlay
      portableOverlay
    ];
  };

  portableModule =
    { lib, ... }:
    {
      # I want a self contained executable so I can't have symlinks that point outside the Nix store.
      repository.symlink.makeCopiesInstead = true;

      programs.nix-index = {
        enable = false;
        symlinkToCacheHome = false;
      };

      programs.home-manager.enable = lib.mkForce false;

      # This removes the dependency on `sd-switch`.
      systemd.user.startServices = lib.mkForce "suggest";
      home = {
        # These variables contain the path to the locale archive in pkgs.glibcLocales.
        # There is no option to prevent Home Manager from making these environment variables and overriding
        # glibcLocales in an overlay would cause too many rebuild so instead I overwrite the environment
        # variables. Now, glibcLocales won't be a dependency.
        sessionVariables = lib.attrsets.optionalAttrs isLinux (
          lib.mkForce {
            LOCALE_ARCHIVE_2_27 = "";
            LOCALE_ARCHIVE_2_11 = "";
          }
        );

        file.".hammerspoon/Spoons/EmmyLua.spoon" = lib.mkForce {
          source = makeEmptyPackage "stub-spoon";
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
            source = makeEmptyPackage "parsers";
          };
        };
      };

      # to remove the flake registry
      nix.enable = false;
    };

  homeConfiguration = self.lib.home.makeHomeConfiguration portablePkgs {
    inherit system;
    configName = "guest";
    isGui = false;
    isHomeManagerRunningAsASubmodule = true;

    modules = [
      "${self.lib.home.moduleBaseDirectory}/profile/system-administration.nix"
      portableModule
    ];
  };
in
homeConfiguration.activationPackage
