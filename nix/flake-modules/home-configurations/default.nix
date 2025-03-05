{
  inputs,
  lib,
  utils,
  withSystem,
  ...
}:
let
  inherit (utils.homeManager) moduleRoot baseModule;
  inherit (builtins)
    attrValues
    mapAttrs
    listToAttrs
    length
    ;
  inherit (inputs.flake-utils.lib) system;
  inherit (inputs.home-manager.lib) homeManagerConfiguration;
  inherit (lib)
    pipe
    nameValuePair
    mergeAttrsList
    mkForce
    ;

  makeEmptyPackage =
    pkgs: packageName:
    pkgs.runCommand "${packageName}-empty" { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';

  # These variables contain the path to the locale archive in
  # pkgs.glibcLocales. There is no option to prevent Home Manager from making
  # these environment variables and overriding glibcLocales in an overlay would
  # cause too many rebuild so instead I overwrite the environment variables.
  # Now glibcLocales won't be a dependency.
  emptySessionVariables = mkForce {
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
        "diffoscopeMinimal"
        "difftastic"
        "nix"
      ]
      [
        (map (packageName: nameValuePair packageName (makeEmptyPackage final packageName)))
        listToAttrs
      ];

  portableModule =
    { lib, pkgs, ... }:
    let
      inherit (lib) mkForce optionalAttrs;
      inherit (pkgs) writeText;
      inherit (pkgs.stdenv) isLinux;
    in
    {
      # I want a self contained executable so I can't have symlinks that point
      # outside the Nix store.
      repository.fileSettings.editableInstall = mkForce false;

      programs = {
        home-manager.enable = mkForce false;
        nix-index = {
          enable = false;
          symlinkToCacheHome = false;
        };
      };

      home = {
        sessionVariables = optionalAttrs isLinux emptySessionVariables;

        file.".hammerspoon/Spoons/EmmyLua.spoon" = mkForce {
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
        startServices = mkForce "suggest";
        sessionVariables = optionalAttrs isLinux emptySessionVariables;
      };

      xdg = {
        mime.enable = mkForce false;

        dataFile = {
          "fzf/fzf-history.txt".source = writeText "fzf-history.txt" "";

          "nvim/site/parser" = mkForce {
            source = makeEmptyPackage pkgs "parsers";
          };
        };
      };

      # to remove the flake registry
      nix.enable = false;
    };

  linuxModule =
    {
      lib,
      pkgs,
      repositoryDirectory,
      ...
    }:
    {
      services.flatpak.packages = [ "org.qbittorrent.qBittorrent" ];

      system = {
        file."/etc/sysctl.d/local.conf".source = "${repositoryDirectory}/dotfiles/sysctl/local.conf";

        activation = {
          # Whenever I resume from suspension on Pop!_OS, I get a black screen
          # and then I have to switch to another tty to reboot. Apparently, the
          # issue is caused by Nvidia. This fix was suggested on the issue
          # tracker[1]. More details on the fix can be found here[2].
          #
          # [1]: https://github.com/pop-os/pop/issues/2605#issuecomment-2526281526
          # [2]: https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks#Preserve_video_memory_after_suspend
          nvidiaSuspensionFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            settings_file='/etc/modprobe.d/bigolu-nvidia-suspension-fix.conf'
            if [[ ! -e $settings_file ]]; then
              setting='options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp'
              echo "$setting" | sudo tee "$settings_file"
              sudo update-initramfs -u -k all
            fi
          '';

          increaseFileWatchLimit = lib.hm.dag.entryAfter [ "installSystemFiles" ] ''
            OLD_PATH="$PATH"
            PATH="$PATH:${pkgs.moreutils}/bin"
            chronic sudo sysctl -p --system
            PATH="$OLD_PATH"
          '';
        };
      };
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
        system: if (length systems) == 1 then configName else "${configName}-${system}";

      makeConfigForSystem =
        system:
        withSystem system (
          { pkgs, ... }:
          let
            inherit (pkgs.stdenv) isLinux;

            homePrefix = if isLinux then "/home" else "/Users";
            homeDirectory = spec.homeDirectory or "${homePrefix}/${username}";
            repositoryDirectory = spec.repositoryDirectory or "${homeDirectory}/code/system-configurations";
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
          homeManagerConfiguration {
            modules = modules ++ [ baseModule ];
            inherit extraSpecialArgs;
            pkgs = if overlay == null then pkgs else pkgs.extend overlay;
          }
        );
    in
    pipe systems [
      (map (system: nameValuePair (getOutputNameForSystem system) (makeConfigForSystem system)))
      listToAttrs
    ];

  makeOutputs = configSpecs: {
    # The 'flake' and 'homeConfigurations' keys need to be static to avoid infinite
    # recursion
    flake.homeConfigurations = pipe configSpecs [
      (mapAttrs (configName: spec: spec // { inherit configName; }))
      attrValues
      (map makeOutputsForSpec)
      mergeAttrsList
    ];
  };
in
makeOutputs {
  linux = {
    systems = with system; [ x86_64-linux ];
    modules = [
      "${moduleRoot}/profile/application-development"
      "${moduleRoot}/profile/speakers.nix"
      linuxModule
    ];
  };

  portable-home = {
    systems = with system; [
      x86_64-linux
      x86_64-darwin
    ];
    modules = [ portableModule ];
    overlay = portableOverlay;
    isGui = false;
    isHomeManagerRunningAsASubmodule = true;
  };
}
