# Remove large or unnecessary packages from the portable shell
pkgs:
let
  inherit (pkgs.lib) foldl' recursiveUpdate setAttrByPath;
  inherit (pkgs) runCommand;

  emptyPackage =
    # `lib.getExe` will be called with these packages so `meta.mainProgram` must be
    # set.
    runCommand "empty-package" { meta.mainProgram = "program"; } ''
      # `pkgs.buildEnv` will be called with these packages and the path "/bin" so
      # "bin" needs to exist.
      mkdir --parents $out/bin
    '';

  makeEmptyPackageSet = foldl' (
    acc: packagePath: recursiveUpdate acc (setAttrByPath packagePath emptyPackage)
  ) { };
in
{
  fish = pkgs.fishMinimal;
  git = pkgs.gitMinimal;
  vimPlugins.nvim-treesitter = emptyPackage // {
    withAllGrammars = emptyPackage // {
      dependencies = [ ];
    };
  };
}
// (makeEmptyPackageSet [
  [
    "lixPackageSet"
    "lix"
  ]
  [ "diffoscopeMinimal" ]
  [ "difftastic" ]
  [ "lesspipe" ]
  [ "ripgrep-all" ]
  [ "timg" ]
  [ "home-manager" ]
])
