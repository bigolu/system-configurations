let
  projectRoot = ../.;

  inherit ((import projectRoot).inputs.nixpkgs.lib)
    concatMapAttrs
    hasSuffix
    removeSuffix
    genAttrs
    ;

  getModules =
    type:
    let
      inherit (builtins) readDir;

      getModule =
        path:
        let
          moduleMap = import path;
        in
        moduleMap.${type} or { };

      directoryToMap =
        directory:
        let
          directoryContents = readDir directory;
        in
        if directoryContents ? "default.nix" then
          getModule directory
        else
          concatMapAttrs (
            name: type:
            if type == "directory" then
              let
                moduleMap = directoryToMap (directory + "/${name}");
              in
              if moduleMap != { } then { "${name}" = moduleMap; } else moduleMap
            else if hasSuffix ".nix" name then
              let
                module = getModule (directory + "/${name}");
              in
              if module != { } then { "${removeSuffix ".nix" name}" = module; } else module
            else
              { }
          ) directoryContents;
    in
    directoryToMap (projectRoot + /nix/modules/host);
in
{
  inherit projectRoot;
  programConfigRoot = projectRoot + /program-configs;
  modules = genAttrs [ "home" "system" "darwin" ] getModules;
  callIf = condition: function: if condition then function else (x: x);
}
