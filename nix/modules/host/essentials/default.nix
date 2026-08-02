{ _class, inputs, ... }:
{
  homeManager.imports = [
    inputs.home-manager-file-wrapper.homeModules.file-wrapper
    ./misc.nix
    ./module-args.nix
    ./shell
  ];

  "".imports = [
    ./application-development
    ./fonts.nix
    ./home-manager.nix
    ./keyboard
    ./login-shell.nix
    ./misc.nix
    ./module-args.nix
    ./nix.nix
    ./non-nixos-gpu-setup.nix
    ./sudo.nix
  ];

  darwin = { modules, ... }: {
    imports = [
      modules.darwin.speakers
      ./application-development
      ./fonts.nix
      ./home-manager.nix
      ./homebrew.nix
      ./keyboard
      ./login-shell.nix
      ./misc.nix
      ./module-args.nix
      ./nix.nix
      ./yabai.nix
    ];
  };
}
.${toString _class}
