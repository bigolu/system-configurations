{
  home = { inputs, ... }: {
    imports = [
      (import ./module-args.nix { type = "home"; })
      ./misc/home.nix
      ./shell-home
      inputs.home-manager-file-wrapper.homeModules.file-wrapper
    ];
  };

  system = { system }: {
    imports = [
      (import ./home-manager-darwin-system.nix "nixos")
      (import ./misc/system.nix { inherit system; })
      (import ./module-args.nix { type = "system"; })
      ./application-development/darwin-system.nix
      ./application-development/system
      ./fonts-darwin-system.nix
      ./misc/darwin-system.nix
      ./keyboard/system.nix
      ./login-shell/darwin-system.nix
      ./nix/darwin-system.nix
      ./non-nixos-gpu-setup-system.nix
      ./sudo-system.nix
    ];
  };

  darwin = {
    imports = with (import ../../../my-utils.nix).modules.darwin; [
      (import ./home-manager-darwin-system.nix "darwin")
      (import ./module-args.nix { type = "darwin"; })
      ./application-development/darwin.nix
      ./application-development/darwin-system.nix
      ./fonts-darwin-system.nix
      ./misc/darwin-system.nix
      ./misc/darwin.nix
      ./homebrew-darwin.nix
      ./keyboard/darwin.nix
      ./login-shell/darwin-system.nix
      ./login-shell/darwin.nix
      ./mac-os-system-settings-darwin.nix
      ./nix/darwin.nix
      ./nix/darwin-system.nix
      ./yabai-darwin.nix
      speakers
    ];
  };
}
