{ _class, inputs, ... }:
{
  homeManager.imports = [
    ./misc.nix
    ./module-args.nix
    ./shell
    inputs.home-manager-file-wrapper.homeModules.file-wrapper
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

  darwin = {
    imports = [
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
      ../speakers.nix
    ];
  };
}
.${toString _class}
