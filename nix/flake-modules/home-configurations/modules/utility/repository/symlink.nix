# This module makes it easy to create symlinks to a file in your Home Manager
# flake. This way you can edit a file and have the changes applied instantly
# without having to switch generations.
#
# TODO: I wouldn't need this if Home Manager did what is suggested here:
# https://github.com/nix-community/home-manager/issues/3032
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkOption
    hasPrefix
    removePrefix
    flatten
    filterAttrs
    sublist
    concatStringsSep
    mapAttrs'
    nameValuePair
    foldlAttrs
    pipe
    splitString
    ;
  inherit (builtins)
    length
    getAttr
    pathExists
    filter
    attrValues
    hasAttr
    readDir
    attrNames
    listToAttrs
    ;
in
{
  # For consistency, these options are made to resemble Home Manager's options
  # for linking files.
  options.repository.symlink =
    let
      inherit (lib) types;
      target = mkOption {
        type = types.str;
      };
      source = mkOption {
        type = types.str;
      };
      executable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        # Marked `internal` and `readOnly` since it needs to be passed to
        # home-manager, but the user shouldn't set it.  This is because
        # permissions on a symlink are ignored, only the source's permissions
        # are considered. Also I got an error when I tried to set it to `true`.
        internal = true;
        readOnly = true;
      };
      recursive = mkOption {
        type = types.bool;
        default = false;
        description = "This links top level files only.";
      };
      symlinkOptions = submoduleContext: {
        options = {
          inherit
            target
            source
            executable
            recursive
            ;
        };
        config = {
          target = mkDefault submoduleContext.config._module.args.name;
        };
      };
      symlinkType = types.submodule symlinkOptions;
      symlinkSetType = types.attrsOf symlinkType;
      executableSymlinkOptions = submoduleContext: {
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
                config.repository.symlink.xdg.executableHome
              else
                "${config.repository.symlink.xdg.executableHome}/${value}";
          };
        };
        config = {
          target = mkDefault submoduleContext.config._module.args.name;
        };
      };
      executableSymlinkType = types.submodule executableSymlinkOptions;
      executableSymlinkSetType = types.attrsOf executableSymlinkType;
    in
    {
      makeCopiesInstead = mkOption {
        type = types.bool;
        default = false;
        description = "Sometimes I run my home configuration in a self contained executable, using `nix bundle`, so I can use it easily on other machines. In those cases I can't have my dotfiles be symlinks since their targets won't exist. This flag is an easy way for me to make copies of everything instead.";
      };

      baseDirectory = mkOption {
        type = types.str;
        description = "When a relative path is used a source in any symlink, it will be assumed that they are relative to this directory.";
      };

      home.file = mkOption {
        type = symlinkSetType;
        default = { };
      };

      xdg = {
        configFile = mkOption {
          type = symlinkSetType;
          default = { };
        };
        dataFile = mkOption {
          type = symlinkSetType;
          default = { };
        };
        executable = mkOption {
          type = executableSymlinkSetType;
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
      flakeDirectory = config.repository.directory;
      makePathStringAbsolute =
        path: if isRelativePath path then "${config.repository.symlink.baseDirectory}/${path}" else path;
      convertAbsolutePathStringToPath =
        pathString:
        let
          # You can make a string into a Path by concatenating it with a
          # Path. However, in flake pure evaluation mode all Paths must be
          # inside the flake directory so we use a Path that points to the flake
          # directory.
          pathStringRelativeToHomeManager = removePrefix flakeDirectory pathString;
          path = config.repository.directoryPath + pathStringRelativeToHomeManager;
        in
        path;
      getFilesRecursive =
        prefix: dir:
        let
          typeByBasename = readDir dir;
        in
        map (
          basename:
          if typeByBasename.${basename} == "directory" then
            getFilesRecursive "${prefix}${basename}/" (dir + "/${basename}")
          else
            {
              name = "${prefix}${basename}";
              value = typeByBasename.${basename};
            }
        ) (attrNames typeByBasename);
      readDirRecursive = directoryPath: listToAttrs (flatten (getFilesRecursive "" directoryPath));
      convertFileToHomeManagerSymlink =
        file:
        let
          absoluteSource = makePathStringAbsolute file.source;
          symlinkSource =
            if
              config.repository.symlink.makeCopiesInstead
            # The flake evaluation engine automatically makes copies of all
            # Paths so we just have to make it a Path.
            then
              convertAbsolutePathStringToPath absoluteSource
            else
              config.lib.file.mkOutOfStoreSymlink absoluteSource;
          homeManagerSymlink = (filterAttrs (k: _v: k != "removeExtension") file) // {
            source = symlinkSource;
            target =
              let
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
              in
              if (file.removeExtension or false) then (removeExtension file.target) else file.target;
          };
        in
        homeManagerSymlink;
      getHomeManagerSymlinkSetForFilesInDirectory =
        directory:
        let
          sourceAbsolutePathString = makePathStringAbsolute directory.source;
          sourcePath = convertAbsolutePathStringToPath sourceAbsolutePathString;
          symlinks = mapAttrs' (
            basename: _ignored:
            # Now that we are dealing with the individual files in the
            # directory, we need to append the file name to the target and
            # source.
            nameValuePair "${directory.target}/${basename}" (convertFileToHomeManagerSymlink {
              source = "${directory.source}/${basename}";
              target = "${directory.target}/${basename}";
              inherit (directory) executable;
              removeExtension = directory.removeExtension or false;
            })
          ) (readDirRecursive sourcePath);
        in
        symlinks;
      convertToHomeManagerSymlinkSet =
        fileSet:
        foldlAttrs (
          accumulator: targetPath: file:
          let
            symlinkSet =
              if (hasAttr "recursive" file) && file.recursive then
                (getHomeManagerSymlinkSetForFilesInDirectory file)
              else
                { ${targetPath} = convertFileToHomeManagerSymlink file; };
          in
          accumulator // symlinkSet
        ) { } fileSet;
      assertions =
        let
          fileSets = with config.repository.symlink; [
            home.file
            xdg.configFile
            xdg.dataFile
            xdg.executable
          ];
          fileLists = map attrValues fileSets;
          files = flatten fileLists;
          getSource = getAttr "source";
          sources = map getSource files;
          # relative paths are assumed to be relative to
          # `config.repository.symlink.baseDirectory`, which we already assert
          # is within the flake directory, so no need to check them.
          absoluteSources = filter (source: !isRelativePath source) sources;
          isPathWithinFlakeDirectory = path: hasPrefix flakeDirectory path;
          sourcesOutsideFlake = filter (path: !isPathWithinFlakeDirectory path) absoluteSources;
          sourcesOutsideFlakeJoined = concatStringsSep " " sourcesOutsideFlake;
          areAllSourcesInsideFlakeDirectory = sourcesOutsideFlake == [ ];
          isBaseDirectoryInsideFlakeDirectory = hasPrefix flakeDirectory config.repository.symlink.baseDirectory;

          doesSourceExist =
            source:
            pipe source [
              makePathStringAbsolute
              convertAbsolutePathStringToPath
              pathExists
            ];
          nonexistentSources = filter (s: !(doesSourceExist s)) sources;
          doAllSymlinkSourcesExist = nonexistentSources == [ ];
          brokenSymlinksJoined = concatStringsSep " " nonexistentSources;
        in
        [
          # If you try to link files from outside the flake you get a strange
          # error along the lines of 'no such file/directory' so instead I make
          # an assertion here since my error will be much clearer.  I think you
          # can link files from anywhere if you pass --impure to home-manager,
          # but I want a pure evaluation.
          {
            assertion = areAllSourcesInsideFlakeDirectory;
            message = "All sources for config.repository.symlink.* must be within the directory of the home-manager flake. Offending paths: ${sourcesOutsideFlakeJoined}";
          }
          {
            assertion = isBaseDirectoryInsideFlakeDirectory;
            message = "config.repository.symlink.baseDirectory must be inside the home-manager flake directory. Base directory: ${config.repository.symlink.baseDirectory}";
          }
          {
            assertion = doAllSymlinkSourcesExist;
            message = "The following symlink sources do not exist: ${brokenSymlinksJoined}";
          }
        ];
    in
    {
      inherit assertions;
      home.file =
        (convertToHomeManagerSymlinkSet config.repository.symlink.home.file)
        // (convertToHomeManagerSymlinkSet config.repository.symlink.xdg.executable);
      xdg.configFile = convertToHomeManagerSymlinkSet config.repository.symlink.xdg.configFile;
      xdg.dataFile = convertToHomeManagerSymlinkSet config.repository.symlink.xdg.dataFile;
    };
}
