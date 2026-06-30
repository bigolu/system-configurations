{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) optionalAttrs hm;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  imports = [
    ./podman.nix
  ];

  services.flatpak = optionalAttrs isLinux {
    packages = [
      "sh.loft.devpod"
    ];
  };

  home = {
    packages = with pkgs; [
      cloudflared
      doppler
      direnv
      llm-agents.claude-code
      zerobox
      pixi
      mise
    ];

    activation.zeroboxWorkaround = hm.dag.entryAfter [ "writeBoundary" ] ''
      cd ~
      for file in .bashrc .zshrc; do
        temp="$file-zerobox-bak"
        mv -f "$file" "$temp"
        cp -f "$temp" "$file"
      done
    '';
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
