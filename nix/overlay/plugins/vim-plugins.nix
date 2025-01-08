{
  inputs,
  makePluginPackages,
  utils,
}:
final: prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib)
    splitString
    pipe
    init
    nameValuePair
    ;
  inherit (builtins)
    readFile
    hasAttr
    listToAttrs
    ;
  inherit (utils) projectRoot toNixpkgsAttr toNixpkgsPname;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        let
          nixpkgsAttrName = toNixpkgsAttr repositoryName;
        in
        if hasAttr nixpkgsAttrName prev.vimPlugins then
          prev.vimPlugins.${nixpkgsAttrName}.overrideAttrs (_old: {
            version = date;
            src = repositorySourceCode;
          })
        else
          final.vimUtils.buildVimPlugin {
            pname = toNixpkgsPname repositoryName;
            version = date;
            src = repositorySourceCode;
          };
    in
    makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

  myVimPlugins =
    let
      getPackage =
        pluginName:
        let
          nixpkgsAttrName = toNixpkgsAttr pluginName;
        in
        final.vimPlugins.${nixpkgsAttrName}
          or (abort "Failed to find package for vim plugin: ${pluginName}. Package name used: ${nixpkgsAttrName}");
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
        # These attribute names do not adhere to nixpkgs' conventions. I'm
        # intentionally doing this so they match the names in my neovim config.
        (map (pluginName: nameValuePair pluginName (getPackage pluginName)))
        listToAttrs
        final.lib.recurseIntoAttrs
      ];
in
{
  inherit myVimPlugins;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake;
}
