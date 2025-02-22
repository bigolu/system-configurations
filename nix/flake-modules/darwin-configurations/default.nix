{
  inputs,
  utils,
  withSystem,
  lib,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib) pipe mergeAttrs optionals;
  inherit (inputs.flake-utils.lib) system;
  inherit (inputs.nix-darwin.lib) darwinSystem;

  homeManagerUtils = utils.homeManager;
  homeManagerBaseModule = homeManagerUtils.baseModule;
  homeManagerModuleRoot = homeManagerUtils.moduleRoot;

  makeHomeManagerDarwinModules =
    {
      username,
      configName,
      homeDirectory,
      repositoryDirectory,
      modules,
      isGui,
    }:
    let
      # SYNC: SPECIAL-ARGS
      extraSpecialArgs = {
        inherit
          configName
          homeDirectory
          isGui
          repositoryDirectory
          username
          utils
          inputs
          ;
        isHomeManagerRunningAsASubmodule = true;
      };
    in
    [
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          inherit extraSpecialArgs;
          useGlobalPkgs = true;
          # This makes home-manager install packages to the same path that it
          # normally does, ~/.nix-profile. Though this is the default now, they
          # are considering defaulting to true later so I'm explicitly setting
          # it to false.
          useUserPackages = false;
          users.${username} = {
            imports = modules ++ [ homeManagerBaseModule ];
          };
        };
      }
    ];

  makeDarwinConfiguration =
    {
      system,
      configName,
      modules,
      homeModules ? [ ],
      includeHome ? true,
      username ? "biggs",
      homeDirectory ? "/Users/${username}",
      repositoryDirectory ? "${homeDirectory}/code/system-configurations",
    }:
    let
      homeManagerSubmodules = makeHomeManagerDarwinModules {
        inherit
          username
          configName
          homeDirectory
          repositoryDirectory
          ;
        modules = homeModules;
        isGui = true;
      };
    in
    withSystem system (
      { pkgs, ... }:
      darwinSystem {
        inherit pkgs;
        modules = modules ++ (optionals includeHome homeManagerSubmodules);
        # SYNC: SPECIAL-ARGS
        specialArgs = {
          inherit
            configName
            username
            homeDirectory
            repositoryDirectory
            utils
            inputs
            ;
        };
      }
    );

  makeOutputs = configSpecs: {
    # The 'flake' and 'darwinConfigurations' keys need to be static to avoid infinite
    # recursion
    flake.darwinConfigurations = pipe configSpecs [
      (mapAttrs (configName: mergeAttrs { inherit configName; }))
      (mapAttrs (_configName: makeDarwinConfiguration))
    ];
  };
in
makeOutputs {
  mac = {
    system = system.x86_64-darwin;
    modules = [
      ./modules/profile/base.nix
    ];
    homeModules = [
      "${homeManagerModuleRoot}/profile/system-administration.nix"
      "${homeManagerModuleRoot}/profile/application-development.nix"
      "${homeManagerModuleRoot}/profile/personal.nix"
    ];
  };

  # Since I use a custom `nix.linux-builder`, I use the linux-builder cached by Nix
  # to build it. So before applying my config for the first time, I apply this one
  # which starts Nix's linux-builder.
  linux-builder-bootstrap = {
    system = system.x86_64-darwin;
    includeHome = false;
    modules = [
      (
        { username, pkgs, ... }:
        {
          system.stateVersion = 4;

          nix = {
            settings = {
              trusted-users = [ username ];
              experimental-features = [
                "nix-command"
                "flakes"
              ];
            };

            linux-builder = {
              # Setting this will erase the VM state, but is necessary for certain
              # config changes[1].
              #
              # [1]: https://github.com/LnL7/nix-darwin/pull/850
              ephemeral = true;

              # For this to work, your user must be a trusted user
              enable = true;

              # TODO: I shouldn't have to set this. The default value causes an eval error
              # because it assumes that `cfg.package.nixosConfig.nixpkgs.hostPlatform` is a
              # set[1], but on my machine it's a string ("x86_64-linux"). According to the
              # nix docs, a string is also a valid value[2] so nix-darwin should be updated
              # to account for it.
              #
              # [1]: https://github.com/LnL7/nix-darwin/blob/6ab392f626a19f1122d1955c401286e1b7cf6b53/modules/nix/linux-builder.nix#L127
              # [2]: https://search.nixos.org/options?channel=24.11&show=nixpkgs.hostPlatform&from=0&size=50&sort=relevance&type=packages&query=nixpkgs.hostPlatform
              systems = [ (builtins.replaceStrings [ "darwin" ] [ "linux" ] pkgs.system) ];
            };
          };
        }
      )
    ];
  };
}
