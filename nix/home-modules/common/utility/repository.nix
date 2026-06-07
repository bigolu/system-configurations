# A wrapper for the Home Manager file options. This wrapper allows you to make an
# "editableInstall" where symlinks are made to files instead of copying them. This
# way you can edit a file and have the changes applied instantly without having to
# switch generations.
#
# Related: https://github.com/nix-community/home-manager/issues/3032
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
    sublist
    concatStringsSep
    nameValuePair
    foldlAttrs
    pipe
    splitString
    length
    pathExists
    filter
    attrValues
    listToAttrs
    hasAttr
    concatMap
    id
    optional
    ;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.strings) unsafeDiscardStringContext;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit (utils) callIf;
  inherit (pkgs) runCommand;
in
{
  options.repository =
    let
      source = mkOption {
        type = types.oneOf [
          types.str
          types.path
        ];
        apply = toString;
      };
      executable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        # Permissions on a symlink are ignored, only the source's permissions
        # are considered.
        internal = config.repository.fileSettings.editableInstall;
        readOnly = config.repository.fileSettings.editableInstall;
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

        directoryFilter = mkOption {
          type = types.functionTo (
            types.oneOf [
              types.str
              types.path
            ]
          );
          default = id;
          description = "This function will be used to filter any directory used as a `source`. It takes a string/path and returns a string/path. For example, you can filter out files that aren't tracked by git.";
        };

        relativePathRoot = {
          symlink = mkOption {
            type = types.oneOf [
              types.str
              types.path
            ];
            apply = toString;
            description = "This is only used if you enable `editableInstall` and use a relative path for the source of any file. Symlinks will be made relative to this directory. You should only need to set this if you use flake pure evaluation.";
            default = config.repository.fileSettings.relativePathRoot.access;
          };

          access = mkOption {
            type = types.oneOf [
              types.str
              types.path
            ];
            apply = toString;
            description = "If you use a relative path for the source of any file, they will be accessed using paths relative to this directory. For example, for listing the files in a directory or filtering its contents.";
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
      isRelativePath = path: !hasPrefix "/" path;
      relativePathRootSymlink = config.repository.fileSettings.relativePathRoot.symlink;
      relativePathRootAccess = config.repository.fileSettings.relativePathRoot.access;
      toAbsolutePathSymlink =
        fileSource:
        if isRelativePath fileSource then "${relativePathRootSymlink}/${fileSource}" else fileSource;
      toAbsolutePathAccess =
        fileSource:
        if isRelativePath fileSource then "${relativePathRootAccess}/${fileSource}" else fileSource;

      toHomeManagerFile =
        file:
        let
          isExecutable = hasAttr "removeExtension";
          isEditableInstall = config.repository.fileSettings.editableInstall;

          replaceShebangInterpreter =
            file:
            runCommand "patched-xdg-executable-${baseNameOf file}" { src = builtins.path { path = file; }; } ''
              cp $src $out
              patchShebangs --host $out
            '';

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
            (
              source:
              if isEditableInstall then
                (mkOutOfStoreSymlink (toAbsolutePathSymlink source))
              else
                toAbsolutePathAccess source
            )
            (callIf (isExecutable file && !isEditableInstall) replaceShebangInterpreter)
          ];

          homeManagerTarget = callIf (file.removeExtension or false) removeExtension file.target;
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
          toAbsolutePathAccess
          config.repository.fileSettings.directoryFilter

          # Use relative paths to account for the case where
          # `repository.fileSettings.relativePathRoot.access` doesn't match
          # `repository.fileSettings.relativePathRoot.symlink`.
          listRelativeFilesRecursive

          (map (
            relativeFile:
            nameValuePair "${directory.target}/${unsafeDiscardStringContext relativeFile}" (toHomeManagerFile {
              source = "${directory.source}/${relativeFile}";
              target = "${directory.target}/${unsafeDiscardStringContext relativeFile}";
              inherit (directory) executable;
              removeExtension = directory.removeExtension or false;
            })
          ))

          listToAttrs
        ];

      toHomeManagerFileSet = foldlAttrs (
        accumulator: target: file:
        let
          homeManagerFileSet =
            if file.recursive or false then
              getHomeManagerFileSetForFilesInDirectory file
            else
              { ${target} = toHomeManagerFile file; };
        in
        accumulator // homeManagerFileSet
      ) { };

      assertions =
        let
          fileSourceExists =
            source:
            pipe source [
              toAbsolutePathAccess
              pathExists
            ];
          fileSets = with config.repository; [
            home.file
            xdg.configFile
            xdg.dataFile
            xdg.executable
          ];
          missingFileSourcesJoined = pipe fileSets [
            (concatMap attrValues)
            (map (file: file.source))
            (filter (source: !(fileSourceExists source)))
            (concatStringsSep " ")
          ];

          allFileSourcesExist = missingFileSourcesJoined == "";
        in
        optional config.repository.fileSettings.editableInstall {
          assertion = allFileSourcesExist;
          message = "The following config.repository file sources do not exist: ${missingFileSourcesJoined}";
        };
    in
    {
      inherit assertions;
      home.file =
        (toHomeManagerFileSet config.repository.home.file)
        // (toHomeManagerFileSet config.repository.xdg.executable);
      xdg.configFile = toHomeManagerFileSet config.repository.xdg.configFile;
      xdg.dataFile = toHomeManagerFileSet config.repository.xdg.dataFile;
    };
}
