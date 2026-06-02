{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) optionalAttrs hm;
  inherit (pkgs.stdenv) isLinux;
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
    ];

    activation.zeroboxWorkaround = hm.dag.entryAfter [ "writeBoundary" ] ''
      cd ~
      for file in .bashrc .bash_profile .zshrc .zlogin; do
        temp="$file-zerobox-bak"
        mv -f "$file" "$temp"
        cp -f "$temp" "$file"
      done
    '';
  };

  repository = {
    home.file = {
      ".yashrc".source = "yash/yashrc";
      ".cloudflared/config.yaml".source = "cloudflared/config.yaml";
    };

    xdg.configFile = {
      "ipython/profile_default/ipython_config.py".source = "python/ipython/ipython_config.py";
      "ipython/profile_default/startup" = {
        source = "python/ipython/startup";
        # I'm linking recursively because ipython makes files in this directory
        recursive = true;
      };
      "direnv/direnv.toml".source = "direnv/direnv.toml";
      "direnv/direnvrc".source = "direnv/direnvrc";
      "direnv/autocomplete-hooks.fish".source = "direnv/autocomplete-hooks.fish";
      # Zed only recognizes the ".json" extension, but it's actually jsonc
      "zed/settings.json".source = "zed/settings.jsonc";
    };
  };
}
