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
    optionals
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
    unsafeDiscardStringContext
    ;
  inherit (utils) applyIf;
  inherit (pkgs) writeScript;

  inFlakePureEval = !builtins ? currentSystem;
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
          type = types.oneOf [
            types.str
            types.path
          ];
          apply = toString;
          description = "Relative paths used as the source for any file are assumed to be relative to this directory.";
          default = if inFlakePureEval then config.repository.fileSettings.flake.root.path else null;
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
      flakePath = config.repository.fileSettings.flake.root.path;
      flakeStorePath = config.repository.fileSettings.flake.root.storePath;
      inherit (config.repository.fileSettings) relativePathRoot;
      isRelativePath = path: !hasPrefix "/" path;
      toAbsolutePath =
        fileSource: if isRelativePath fileSource then "${relativePathRoot}/${fileSource}" else fileSource;

      toPath =
        fileSource:
        pipe fileSource (
          [
            toAbsolutePath
          ]
          ++ optionals inFlakePureEval [
            # You can make a string into a Path by concatenating it with a Path.
            # However, in flake pure evaluation mode all Paths must be inside the the
            # nix store so we remove the path to the flake root and then append the
            # result to the store path for the flake.
            (removePrefix flakePath)
            (sourceRelativeToFlakeRoot: flakeStorePath + sourceRelativeToFlakeRoot)
          ]
        );

      toHomeManagerFile =
        file:
        let
          isExecutable = hasAttr "removeExtension";
          isEditableInstall = config.repository.fileSettings.editableInstall;

          replaceShebangInterpreter =
            file:
            pipe file [
              readFile
              (replaceString "/usr/bin/env bash" (getExe pkgs.bash))
              (writeScript "patched-xdg-executable-${baseNameOf file}")
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
            toAbsolutePath
            (if isEditableInstall then mkOutOfStoreSymlink else toPath)
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
          toPath

          # Flakes have built-in gitignore support
          (applyIf (!inFlakePureEval) utils.gitFilter)

          # Use relative paths to account for the case where the source directory
          # doesn't match the directory we list the files from. This can happen for
          # two reasons:
          #   - In flake pure eval mode, we can only read from the nix store
          #   - `gitFilter` return a new directory in the nix store
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
          # TODO: These paths should be normalized first
          isRelativePathRootInFlakeDirectory = hasPrefix flakePath relativePathRoot;

          fileSourceExists =
            source:
            pipe source [
              toPath
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
            assertion = allFileSourcesExist;
            message = "The following config.repository file sources do not exist: ${missingFileSourcesJoined}";
          }
        ]
        ++ optionals inFlakePureEval [
          {
            assertion = isRelativePathRootInFlakeDirectory;
            message = "config.repository.fileSettings.relativePathRoot must be inside the flake directory. relativePathRoot: ${relativePathRoot}, flake directory: ${flakePath}";
          }
        ];
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
