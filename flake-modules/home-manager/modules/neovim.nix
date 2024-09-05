{
  pkgs,
  config,
  specialArgs,
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

  luarc =
    pkgs.runCommand
    "luarc.json"
    {nativeBuildInputs = with pkgs; [neovim jq];}
    ''
      # Read this to see why the `tr` command is needed:
      # https://stackoverflow.com/questions/16739300/redirect-ex-command-to-stdout-in-vim
      #
      # The grep command is there to filter out any messages that get printed on startup.
      # I'm redirecting stderr to stdout because neovim prints its output on stderr.
      readarray -t runtime_dirs < <(nvim --headless  -c 'lua for _,directory in ipairs(vim.api.nvim_get_runtime_file("", true)) do print(directory) end' -c 'quit' 2>&1 | tr -d '\r' | grep -E '^/')

      jq \
        --null-input \
        '{"$schema": "https://raw.githubusercontent.com/sumneko/vscode-lua/master/setting/schema.json", "diagnostics": {"unusedLocalExclude": ["_*"]}, "workspace": {"library": $ARGS.positional, "checkThirdParty": "Disable"}, "runtime": {"version": "LuaJIT", "path": [ "dotfiles/neovim/lua/?.lua", "dotfiles/neovim/lua/?/init.lua" ]}, "telemetry": {"enable": false}, "hint": {"enable": true}}' \
        --args \
          '${specialArgs.flakeInputs.neodev-nvim}/types/nightly' \
          '${config.xdg.dataHome}/nvim/plugged' \
          '${specialArgs.homeDirectory}/.hammerspoon/Spoons/EmmyLua.spoon/annotations' \
          "''${runtime_dirs[@]}" \
        > $out
    '';
in {
  home = {
    packages = with pkgs; [
      page
      neovim
    ];

    file = {
      "${config.repository.directory}/.luarc.json".source = luarc;

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
