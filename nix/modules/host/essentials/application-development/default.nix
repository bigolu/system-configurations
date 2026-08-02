{
  _class,
  primaryUser,
  pkgs,
  ...
}:
let
  darwinAndSystem = {
    home-manager.users.${primaryUser} = {
      home = {
        packages = with pkgs; [
          cloudflared
          doppler
          direnv
          llm-agents.claude-code
          pixi
          mise
          quickemu
        ];
      };

      fileWrapper = {
        home.file = {
          ".yashrc".source = "yash/yashrc";
          ".cloudflared/config.yaml".source = "cloudflared/config.yaml";
        };

        xdg.configFile = {
          "ipython/profile_default/ipython_config.py".source = "python/ipython/ipython_config.py";
          "direnv/direnv.toml".source = "direnv/direnv.toml";
          # Zed only recognizes the ".json" extension, but it's actually jsonc
          "zed/settings.json".source = "zed/settings.jsonc";
          "ghostty/config.ghostty".source = "ghostty/config.ghostty";
          "ghostty/themes".source = "ghostty/themes";
        };
      };
    };
  };
in
{
  "" = {
    imports = [
      darwinAndSystem
      ./podman.nix
    ];

    home-manager.users.${primaryUser}.home.packages = with pkgs; [
      ghostty
      vscode
    ];
  };

  darwin = {
    imports = [ darwinAndSystem ];

    homebrew.casks = [
      "ghostty"
      "visual-studio-code"
      "podman-desktop"
    ];
  };
}
.${toString _class}
