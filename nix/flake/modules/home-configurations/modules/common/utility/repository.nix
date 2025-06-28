# A wrapper for the Home Manager file options. This wrapper allows you to make an
# "editableInstall" where symlinks are made to files instead of copying them. This
# way you can edit a file and have the changes applied instantly without having to
# switch generations.
#
# TODO: I probably wouldn't need this if Home Manager did what is suggested here:
# https://github.com/nix-community/home-manager/issues/3032

{
  lib,
  config,
  utils,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    mkDefault
    mkOption
    hasPrefix
    removePrefix
    flatten
    sublist
    concatStringsSep
    nameValuePair
    foldlAttrs
    pipe
    splitString
    getExe
    replaceString
    ;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit (builtins)
    length
    pathExists
    filter
    attrValues
    listToAttrs
    readFile
    hasAttr
    ;
  inherit (utils) applyIf;
  inherit (pkgs) writeScript;
in
{
  options.repository =
    let
      source = mkOption {
        type = types.str;
      };
      executable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        # Marked `internal` and `readOnly` since it needs to be passed to
        # home-manager, but the user shouldn't set it. This is because permissions
        # on a symlink are ignored, only the source's permissions are considered.
        # Also I got an error when I tried to set it to `true`.
        internal = true;
        readOnly = true;
      };
      recursive = mkOption {
        type = types.bool;
        default = false;
      };

      attrsOfSubmodule =
        submoduleDefinition:
        pipe submoduleDefinition [
          types.submodule
          types.attrsOf
        ];

      fileSetType = attrsOfSubmodule (submoduleContext: {
        options = {
          inherit
            source
            executable
            recursive
            ;

          target = mkOption {
            type = types.str;
          };

          force = mkOption {
            type = types.bool;
            default = false;
          };
        };
        config = {
          target = mkDefault submoduleContext.config._module.args.name;
        };
      });

      executableSetType = attrsOfSubmodule (submoduleContext: {
        options = {
          inherit source executable recursive;
          removeExtension = mkOption {
            type = types.nullOr types.bool;
            default = true;
            internal = true;
            readOnly = true;
          };
          target = mkOption {
            type = types.str;
            apply =
              value:
              if submoduleContext.config.recursive then
                config.repository.xdg.executableHome
              else
                "${config.repository.xdg.executableHome}/${value}";
          };
        };
        config = {
          target = mkDefault submoduleContext.config._module.args.name;
        };
      });
    in
    {
      fileSettings = {
        editableInstall = mkOption {
          type = types.bool;
          default = false;
          description = "Use symlinks instead of copies.";
        };

        relativePathRoot = mkOption {
          type = types.str;
          description = "Relative paths used as the source for any file are assumed to be relative to this directory.";
          default = config.repository.fileSettings.flake.root.path;
        };

        flake.root = {
          # Only needed to turn absolute path strings to Paths if flake pure eval is
          # enabled.
          path = mkOption {
            type = types.str;
            description = "Absolute path to the root of the flake.";
          };
          storePath = mkOption {
            type = types.path;
            description = "Store path of the flake";
          };
        };
      };

      home.file = mkOption {
        type = fileSetType;
        default = { };
      };

      xdg = {
        configFile = mkOption {
          type = fileSetType;
          default = { };
        };
        dataFile = mkOption {
          type = fileSetType;
          default = { };
        };
        executable = mkOption {
          type = executableSetType;
          default = { };
        };
        executableHome = mkOption {
          type = types.path;
          default = "${config.home.homeDirectory}/.local/bin";
          readOnly = true;
        };
      };
    };

  config =
    let
      flakeRootPath = config.repository.fileSettings.flake.root.path;
      flakeRootStorePath = config.repository.fileSettings.flake.root.storePath;
      inherit (config.repository.fileSettings) relativePathRoot;
      isRelativePath = path: !hasPrefix "/" path;
      mapFileSourceToAbsolutePath =
        source: if isRelativePath source then "${relativePathRoot}/${source}" else source;

      mapFileSourceToPathBuiltin =
        fileSource:
        pipe fileSource [
          mapFileSourceToAbsolutePath
          # You can make a string into a Path by concatenating it with a Path.
          # However, in flake pure evaluation mode all Paths must be inside the the
          # nix store so we remove the path to the flake root and then append the
          # result to the store path for the flake.
          (removePrefix flakeRootPath)
          (sourceRelativeToFlakeRoot: flakeRootStorePath + sourceRelativeToFlakeRoot)
        ];

      mapToHomeManagerFile =
        file:
        let
          isExecutable = hasAttr "removeExtension";
          isEditableInstall = config.repository.fileSettings.editableInstall;

          makeSymlinkOrCopy =
            if isEditableInstall then
              mkOutOfStoreSymlink
            else
              # Flake evaluation automatically makes copies of all Paths so we just
              # have to make it a Path.
              mapFileSourceToPathBuiltin;

          replaceShebangInterpreter =
            file:
            pipe file [
              readFile
              (replaceString "/usr/bin/env bash" (getExe pkgs.bash))
              (writeScript "patched-xdg-executable")
            ];

          removeExtension =
            path:
            let
              basename = baseNameOf path;
              basenamePieces = splitString "." basename;
              baseNameWithoutExtension =
                if length basenamePieces == 1 then
                  basename
                else
                  concatStringsSep "." (sublist 0 ((length basenamePieces) - 1) basenamePieces);
            in
            if basename == path then baseNameWithoutExtension else "${dirOf path}/${baseNameWithoutExtension}";

          removeNonHomeManagerAttrs = file: removeAttrs file [ "removeExtension" ];

          homeManagerSource = pipe file.source [
            mapFileSourceToAbsolutePath
            makeSymlinkOrCopy
            (applyIf (isExecutable file && !isEditableInstall) replaceShebangInterpreter)
          ];

          homeManagerTarget = applyIf (file.removeExtension or false) removeExtension file.target;
        in
        pipe file [
          removeNonHomeManagerAttrs
          (
            file:
            file
            // {
              source = homeManagerSource;
              target = homeManagerTarget;
            }
          )
        ];

      listRelativeFilesRecursive =
        directory:
        pipe directory [
          listFilesRecursive
          (map (path: removePrefix "${toString directory}/" (toString path)))
        ];

      getHomeManagerFileSetForFilesInDirectory =
        directory:
        pipe directory.source [
          mapFileSourceToPathBuiltin
          listRelativeFilesRecursive
          (map (
            relativeFile:
            nameValuePair "${directory.target}/${relativeFile}" (mapToHomeManagerFile {
              source = "${directory.source}/${relativeFile}";
              target = "${directory.target}/${relativeFile}";
              inherit (directory) executable;
              removeExtension = directory.removeExtension or false;
            })
          ))
          listToAttrs
        ];

      mapToHomeManagerFileSet = foldlAttrs (
        accumulator: target: file:
        let
          homeManagerFileSet =
            if file.recursive or false then
              getHomeManagerFileSetForFilesInDirectory file
            else
              { ${target} = mapToHomeManagerFile file; };
        in
        accumulator // homeManagerFileSet
      ) { };

      assertions =
        let
          # TODO: The paths should be normalized first
          isRelativePathRootInsideFlakeDirectory = hasPrefix flakeRootPath relativePathRoot;

          fileSourceExists =
            source:
            pipe source [
              mapFileSourceToPathBuiltin
              pathExists
            ];
          fileSets = with config.repository; [
            home.file
            xdg.configFile
            xdg.dataFile
            xdg.executable
          ];
          missingFileSourcesJoined = pipe fileSets [
            (map attrValues)
            flatten
            (map (file: file.source))
            (filter (source: !(fileSourceExists source)))
            (concatStringsSep " ")
          ];

          allFileSourcesExist = missingFileSourcesJoined == "";
        in
        [
          {
            assertion = isRelativePathRootInsideFlakeDirectory;
            message = "config.repository.fileSettings.relativePathRoot must be inside the flake directory. relativePathRoot: ${relativePathRoot}";
          }
          {
            assertion = allFileSourcesExist;
            message = "The following config.repository file sources do not exist: ${missingFileSourcesJoined}";
          }
        ];
    in
    {
      inherit assertions;
      home.file =
        (mapToHomeManagerFileSet config.repository.home.file)
        // (mapToHomeManagerFileSet config.repository.xdg.executable);
      xdg.configFile = mapToHomeManagerFileSet config.repository.xdg.configFile;
      xdg.dataFile = mapToHomeManagerFileSet config.repository.xdg.dataFile;
    };
}
