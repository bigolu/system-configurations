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
    toLower
    nameValuePair
    ;
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
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-naming
      # This doesn't apply all of the conventions, but it's enough for now.
      applyNixpkgsNamingConventions =
        name:
        pipe name [
          (replaceStrings [ "." ] [ "-" ])
          toLower
        ];

      getPackage =
        pluginName:
        let
          packageName = applyNixpkgsNamingConventions pluginName;
        in
        final.vimPlugins.${packageName}
          or (abort "Failed to find package for vim plugin: ${pluginName}. Package name used: ${packageName}");
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
        (map (pluginName: nameValuePair pluginName (getPackage pluginName)))
        listToAttrs
        final.lib.recurseIntoAttrs
      ];
in
{
  inherit myVimPlugins;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake;
}
