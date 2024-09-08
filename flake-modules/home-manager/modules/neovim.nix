{
  pkgs,
  config,
  ...
}: let
  firenvimScriptPath = ".local/share/firenvim/firenvim";

  firenvimManifestPath = let
    firefoxExtensionManifestDirectory =
      if pkgs.stdenv.isLinux
      then ".mozilla/native-messaging-hosts"
      else "Library/Application Support/Mozilla/NativeMessagingHosts";
  in "${firefoxExtensionManifestDirectory}/firenvim.json";

  firenvimOutput =
    pkgs.runCommand "firenvim-manifest"
    {}
    ''
      # By default Nix adds a bunch of programs to the $PATH and the script that firenvim generates
      # will includes the contents of the $PATH so to avoid pulling in unnecessary dependencies, I'm
      # explicitly setting the $PATH here.
      PATH="${pkgs.neovim}/bin:${pkgs.coreutils-full}/bin"

      home="$out"

      packpath="$home/.local/share/nvim/site/pack/foo/start"
      mkdir -p "$packpath"

      ln --symbolic ${pkgs.vimPlugins.firenvim} "$packpath/firenvim"

      # TODO: firenvim resolves the runtime directory at build time which is a problem for Nix since
      # it gets built in a sandbox. I'm hardcoding /tmp for now, but I should see if upstream can
      # resolve the runtime directory at runtime instead. Plus it feel weird to set a runtime
      # directoy at build time since there is no guarantee that directory won't be taken by the
      # time firenvim actually runs.
      HOME="$home" XDG_RUNTIME_DIR="/tmp" nvim --headless -c 'lua vim.fn["firenvim#install"](1)' -c quit
    '';
in {
  home = {
    packages = with pkgs; [
      page
      neovim
    ];

    file = {
      # TODO: I should upstream this, there's a feature request open for it:
      # https://github.com/NixOS/nixpkgs/issues/77633
      "${firenvimManifestPath}".source = "${firenvimOutput}/${firenvimManifestPath}";
      "${firenvimScriptPath}".source = "${firenvimOutput}/${firenvimScriptPath}";
    };
  };

  repository.symlink.xdg.configFile = {
    "nvim" = {
      source = "neovim";
    };
  };

  vimPlug.pluginFile = config.repository.directoryPath + "/dotfiles/neovim/plugin-names.txt";
}
