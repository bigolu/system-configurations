{ pkgs, inputs }:
let
  inherit (pkgs) lib;

  pluginsByName =
    let
      pluginNames = builtins.filter (name: name != "") (
        lib.strings.splitString "\n" (builtins.readFile "${inputs.self}/dotfiles/neovim/plugin-names.txt")
      );
      replaceDotsWithDashes = builtins.replaceStrings [ "." ] [ "-" ];
    in
    builtins.listToAttrs (
      map (
        pluginName:
        let
          getPackageForPlugin = builtins.getAttr pluginName;
          formattedPluginName = replaceDotsWithDashes pluginName;
          package =
            if builtins.hasAttr pluginName pkgs.vimPlugins then
              getPackageForPlugin pkgs.vimPlugins
            else if builtins.hasAttr formattedPluginName pkgs.vimPlugins then
              (builtins.getAttr "overrideAttrs" (builtins.getAttr formattedPluginName pkgs.vimPlugins)) (_old: {
                pname = pluginName;
              })
            else
              abort "Failed to find vim plugin: ${pluginName}";
        in
        {
          name = pluginName;
          value = package;
        }
      ) pluginNames
    );
in
pkgs.symlinkJoin {
  name = "lua-ls-libraries";
  paths = [ ];
  postBuild = ''
    cd $out
    ln -s ${lib.escapeShellArg (pkgs.linkFarm "plugins" pluginsByName)} ./plugins
    ln -s ${lib.escapeShellArg inputs.neodev-nvim}/types/nightly ./neodev
    ln -s ${lib.escapeShellArg pkgs.neovim}/share/nvim/runtime ./nvim-runtime
  '';
}
