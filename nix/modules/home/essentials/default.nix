{ hasGui, hostName }:
{
  pkgs,
  lib,
  inputs,
  config,
  utils,
  repositoryDirectory,
  ...
}:
let
  inherit (builtins) storeDir;
  inherit (lib)
    optionalAttrs
    optionals
    inPureEvalMode
    isPath
    cleanSourceWith
    hasPrefix
    ;

  inherit (utils) projectRoot callIf;
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  isLinuxAndHasGui = isLinux && hasGui;

  directoryFilter =
    let
      # PERF: As per the documentation[1], we memoize this.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      filter = inputs.gitignore.lib.gitignoreFilterWith { basePath = projectRoot; };
    in
    stringOrPath:
    cleanSourceWith {
      inherit filter;
      # Clean source won't accept a string
      src =
        if (isPath stringOrPath || hasPrefix storeDir stringOrPath) then
          stringOrPath
        else
          /. + stringOrPath;
    };
in
{
  imports = [
    inputs.home-manager-file-wrapper.homeModules.file-wrapper
    ./login-shell.nix
    ./fonts.nix
    ./home-manager.nix
    ./keyboard.nix
    ./nix.nix
    ./terminal
  ];

  _module.args = {
    inherit hasGui hostName;
    repositoryDirectory = "${config.home.homeDirectory}/code/system-configurations";
    pins = import ../../../pins pkgs;
    utils = import ../../../utils.nix;
  };

  home = {
    packages =
      with pkgs;
      optionals config.fileWrapper.settings.editableInstall [
        # For my shebang scripts
        bash
      ]
      ++ optionals isLinuxAndHasGui [
        # TODO: Only doing this because Pop!_OS doesn't come with it by default,
        # but I think it should
        wl-clipboard
      ];
  };

  fileWrapper.settings = {
    editableInstall = true;

    relativePathRoot = {
      access = (if inPureEvalMode then inputs.self.outPath else projectRoot) + "/program-configs";
    }
    // optionalAttrs inPureEvalMode { symlink = "${repositoryDirectory}/program-configs"; };

    # Flakes have built-in gitignore support
    directoryFilter = callIf (!inPureEvalMode) directoryFilter;
  };
}
