{
  home = args: { inputs, ... }: {
    imports = [
      (import ./general/home.nix args)
      ./terminal-home
      inputs.home-manager-file-wrapper.homeModules.file-wrapper
    ];
  };

  system = args: {
    imports = [
      (import ./general/system.nix args)
      (import ./home-manager-darwin-system.nix "nixos")
      ./application-development/darwin-system.nix
      ./application-development/system.nix
      ./fonts-darwin-system.nix
      ./general/darwin-system.nix
      ./keyboard/system.nix
      ./login-shell/darwin-system.nix
      ./nix/darwin-system.nix
      ./non-nixos-gpu-setup-system.nix
      ./sudo-system.nix
    ];
  };

  darwin = {
    imports = with (import ../../../utils.nix).modules.darwin; [
      (import ./home-manager-darwin-system.nix "darwin")
      ./application-development/darwin-system.nix
      ./fonts-darwin-system.nix
      ./general/darwin-system.nix
      ./general/darwin.nix
      ./homebrew-darwin.nix
      ./keyboard/darwin.nix
      ./login-shell/darwin-system.nix
      ./login-shell/darwin.nix
      ./mac-os-system-settings-darwin.nix
      ./nix/darwin
      ./nix/darwin-system.nix
      ./skhd-darwin.nix
      ./yabai-darwin.nix
      speakers
    ];
  };
}
