# This module makes it easy to create symlinks to a file in your Home Manager
# flake. This way you can edit a file and have the changes applied instantly
# without having to switch generations.
{
  config,
  lib,
  ...
}:
{
  # For consistency, these options are made to resemble Home Manager's options
  # for linking files.
  options.repository.symlink =
    let
      inherit (lib) types;
      target = lib.mkOption {
        type = types.str;
      };
      source = lib.mkOption {
        type = types.str;
      };
      executable = lib.mkOption {
        type = types.nullOr types.bool;
        default = null;
        # Marked `internal` and `readOnly` since it needs to be passed to
        # home-manager, but the user shouldn't set it.  This is because
        # permissions on a symlink are ignored, only the source's permissions
        # are considered. Also I got an error when I tried to set it to `true`.
        internal = true;
        readOnly = true;
      };
      recursive = lib.mkOption {
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
          target = lib.mkDefault submoduleContext.config._module.args.name;
        };
      };
      symlinkType = types.submodule symlinkOptions;
      symlinkSetType = types.attrsOf symlinkType;
      executableSymlinkOptions = submoduleContext: {
        options = {
          inherit source executable recursive;
          target = lib.mkOption {
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
          target = lib.mkDefault submoduleContext.config._module.args.name;
        };
      };
      executableSymlinkType = types.submodule executableSymlinkOptions;
      executableSymlinkSetType = types.attrsOf executableSymlinkType;
    in
    {
      makeCopiesInstead = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Sometimes I run my home configuration in a self contained executable, using `nix bundle`, so I can use it easily on other machines. In those cases I can't have my dotfiles be symlinks since their targets won't exist. This flag is an easy way for me to make copies of everything instead.";
      };

      baseDirectory = lib.mkOption {
        type = types.str;
        description = "When a relative path is used a source in any symlink, it will be assumed that they are relative to this directory.";
      };

      home.file = lib.mkOption {
        type = symlinkSetType;
        default = { };
      };

      xdg = {
        configFile = lib.mkOption {
          type = symlinkSetType;
          default = { };
        };
        dataFile = lib.mkOption {
          type = symlinkSetType;
          default = { };
        };
        executable = lib.mkOption {
          type = executableSymlinkSetType;
          default = { };
        };
        executableHome = lib.mkOption {
          type = types.path;
          default = "${config.home.homeDirectory}/.local/bin";
          readOnly = true;
        };
      };
    };

  config =
    let
      isRelativePath = path: !lib.hasPrefix "/" path;
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
          pathStringRelativeToHomeManager = lib.strings.removePrefix flakeDirectory pathString;
          path = config.repository.directoryPath + pathStringRelativeToHomeManager;
        in
        path;
      getFilesRecursive =
        prefix: dir:
        let
          typeByBasename = builtins.readDir dir;
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
        ) (builtins.attrNames typeByBasename);
      readDirRecursive =
        directoryPath: builtins.listToAttrs (lib.lists.flatten (getFilesRecursive "" directoryPath));
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
          homeManagerSymlink = file // {
            source = symlinkSource;
          };
        in
        homeManagerSymlink;
      # TODO: I won't need this if Home Manager gets support for recursive symlinks.
      # issue: https://github.com/nix-community/home-manager/issues/3514
      getHomeManagerSymlinkSetForFilesInDirectory =
        directory:
        let
          sourceAbsolutePathString = makePathStringAbsolute directory.source;
          sourcePath = convertAbsolutePathStringToPath sourceAbsolutePathString;
          symlinks = lib.attrsets.mapAttrs' (
            basename: _ignored:
            # Now that we are dealing with the individual files in the
            # directory, we need to append the file name to the target and
            # source.
            lib.attrsets.nameValuePair "${directory.target}/${basename}" (convertFileToHomeManagerSymlink {
              source = "${directory.source}/${basename}";
              target = "${directory.target}/${basename}";
              inherit (directory) executable;
            })
          ) (readDirRecursive sourcePath);
        in
        symlinks;
      convertToHomeManagerSymlinkSet =
        fileSet:
        lib.attrsets.foldlAttrs (
          accumulator: targetPath: file:
          let
            symlinkSet =
              if (builtins.hasAttr "recursive" file) && file.recursive then
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
          fileLists = map builtins.attrValues fileSets;
          files = lib.lists.flatten fileLists;
          getSource = builtins.getAttr "source";
          sources = map getSource files;
          # relative paths are assumed to be relative to
          # `config.repository.symlink.baseDirectory`, which we already assert
          # is within the flake directory, so no need to check them.
          absoluteSources = builtins.filter (source: !isRelativePath source) sources;
          isPathWithinFlakeDirectory = path: lib.hasPrefix flakeDirectory path;
          sourcesOutsideFlake = builtins.filter (path: !isPathWithinFlakeDirectory path) absoluteSources;
          sourcesOutsideFlakeJoined = lib.concatStringsSep " " sourcesOutsideFlake;
          areAllSourcesInsideFlakeDirectory = sourcesOutsideFlake == [ ];
          isBaseDirectoryInsideFlakeDirectory = lib.strings.hasPrefix flakeDirectory config.repository.symlink.baseDirectory;

          doesSourceExist =
            source:
            lib.trivial.pipe source [
              makePathStringAbsolute
              convertAbsolutePathStringToPath
              builtins.pathExists
            ];
          nonexistentSources = builtins.filter (s: !(doesSourceExist s)) sources;
          doAllSymlinkSourcesExist = nonexistentSources == [ ];
          brokenSymlinksJoined = lib.concatStringsSep " " nonexistentSources;
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
