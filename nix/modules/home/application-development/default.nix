{ pkgs, ... }: {
  imports = [ ./podman.nix ];

  home = {
    packages = with pkgs; [
      cloudflared
      doppler
      direnv
      llm-agents.claude-code
      pixi
      mise
      vscode
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
    };
  };
}
