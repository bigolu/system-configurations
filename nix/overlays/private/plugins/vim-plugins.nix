{
  inputs,
  makePluginPackages,
  utils,
}:
final: prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) splitString pipe init;
  inherit (builtins)
    readFile
    hasAttr
    replaceStrings
    listToAttrs
    ;
  inherit (utils) projectRoot;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        if hasAttr repositoryName prev.vimPlugins then
          prev.vimPlugins.${repositoryName}.overrideAttrs (_old: {
            name = "${repositoryName}-${date}";
            version = date;
            src = repositorySourceCode;
          })
        else
          final.vimUtils.buildVimPlugin {
            pname = repositoryName;
            version = date;
            src = repositorySourceCode;
          };
    in
    makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

  myVimPlugins =
    let
      replaceDotsWithDashes = replaceStrings [ "." ] [ "-" ];
    in
    pipe
      (final.runCommand "neovim-plugin-names"
        {
          nativeBuildInputs = with final; [
            ast-grep
            jq
            coreutils
            gnused
          ];
        }
        ''
          # shellcheck disable=SC2016
          # The dollar signs are for ast-grep
          ast-grep --lang lua --pattern 'Plug($ARG $$$)' --json=compact ${
            projectRoot + /dotfiles/neovim/lua
          } \
            | jq --raw-output '.[].metaVariables.single.ARG.text' \
            | cut -d'/' -f2 \
            | sed 's/.$//' \
            | sort --ignore-case --dictionary-order --unique \
            > $out
        ''
      )
      [
        readFile
        (splitString "\n")
        # The file ends in a newline so the last line will be empty
        init
        (map (
          pluginName:
          final.vimPlugins.${pluginName} or final.vimPlugins.${replaceDotsWithDashes pluginName}
          or (abort "Failed to find vim plugin: ${pluginName}")
        ))
        (map (plugin: {
          name = plugin.pname;
          value = plugin;
        }))
        listToAttrs
        final.lib.recurseIntoAttrs
      ];
in
{
  inherit myVimPlugins;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake;
}
