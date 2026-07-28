let
  primaryUser = {
    _module.args.primaryUser = "biggs";
  };

  # For my shebang scripts
  bash =
    {
      pkgs,
      lib,
      config,
      primaryUser,
      ...
    }:
    let
      inherit (lib) optionals;
    in
    {
      home-manager.users.${primaryUser}.home.packages =
        optionals config.home-manager.users.${primaryUser}.fileWrapper.settings.editableInstall
          [ pkgs.bash ];
    };
in
{
  home = args: {
    imports = [
      (import ./essentials/home args)
      ./home-manager/home.nix
    ];
  };

  system = args: {
    imports = [
      (import ./essentials/system args)
      ./nix/darwin-system.nix
      ./fonts-darwin-system.nix
      (import ./home-manager/darwin-system.nix "nixos")
      ./keyboard/system.nix
      ./application-development/darwin-system.nix
      ./application-development/system.nix
      ./login-shell/darwin-system.nix
      primaryUser
      bash
    ];
  };

  darwin = {
    imports = [
      ./essentials/darwin
      ./nix/darwin
      ./nix/darwin-system.nix
      ./fonts-darwin-system.nix
      (import ./home-manager/darwin-system.nix "darwin")
      ./keyboard/darwin.nix
      ./application-development/darwin-system.nix
      ./login-shell/darwin.nix
      ./login-shell/darwin-system.nix
      primaryUser
      bash
    ];
  };
}
