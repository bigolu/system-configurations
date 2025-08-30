# Generate an attrset of your project's outputs based on their filesystem layout.
# If a default.nix file is found, that directory will not be traversed any further.
#
# Example:
#   Directory structure:
#     outputs/
#       homeConfigurations/
#         default.nix
#         modules/
#           one.nix
#           two.nix
#       packages/
#         package1.nix
#         package2.nix
#   Outputs attrset:
#     {
#       homeConfigurations = <result of `import default.nix context`>;
#       packages = {
#         package1 = <result of `import package1.nix context`>;
#         package2 = <result of `import package2.nix context`>;
#       };
#       context;
#       currentPlatformChecks;
#     }
#
# Arguments:
#   lib (attrset):
#     lib from nixpkgs
#   root (Path):
#     The directory that contains the outputs
#   context (attrset|function -> attrset):
#     A set that gets passed to each of the output files. If it's a function, then it
#     gets called with itself. This is useful if some of the parts of the context
#     depend on other parts of it. The outputs attrset will automatically be
#     added to this set so outputs can refer to each other. The system and output name will also be added.
#   system (string):
#     In pure evaluation mode, the current system can't be accessed so this
#     needs to be passed in.
#
# Return:
#   An attrset containing the outputs. The context will also be added to the attrset
#   since it can be useful to access it from outside of an output file. For example,
#   debugging in the REPL. The key "currentPlatformChecks" will also be added to
#   the outputs and will contain only the checks that support the current platform.
#   This is useful for running checks in CI. It uses any derivations found in
#   `outputs.checks` and automatically generates checks for
#   outputs.{packages,devShells,homeConfigurations,darwinConfigurations}.
{
  root,
  context,
  lib,
  system,
}:
lib.fix (
  self:
  let
    inherit (builtins) baseNameOf;
    inherit (lib)
      pathExists
      filter
      foldl'
      pipe
      removePrefix
      fileset
      splitString
      recursiveUpdate
      setAttrByPath
      init
      last
      optional
      removeSuffix
      mapAttrs
      isFunction
      filterAttrs
      toFunction
      concatMapAttrs
      mapAttrs'
      nameValuePair
      hasPrefix
      optionalAttrs
      ;
    inherit (lib.meta) availableOn;

    fullContext = (toFunction context fullContext) // {
      outputs = self;
      inherit system;
    };

    makeOutputsForFile =
      file:
      let
        relativePath = removePrefix "${toString root}/" (toString file);
        parts = splitString "/" relativePath;
        basename = last parts;
        keys = (init parts) ++ optional (basename != "default.nix") (removeSuffix ".nix" basename);
      in
      setAttrByPath keys (import file (fullContext // { name = last keys; }));

    shouldMakeOutputs =
      file:
      let
        hasAncestorDefaultNix =
          dir:
          pathExists (dir + /default.nix)
          || (if dir == root then false else hasAncestorDefaultNix (dirOf dir));
        dir = dirOf file;
      in
      if (baseNameOf file) == "default.nix" then
        dir == root || !(hasAncestorDefaultNix (dirOf dir))
      else
        !hasAncestorDefaultNix dir;

    makeAutoChecks =
      let
        prefixAttrNames = prefix: mapAttrs' (name: nameValuePair "${prefix}-${name}");

        handlers = {
          packages =
            packages:
            let
              nonFunctionPackages = filterAttrs (_k: v: !isFunction v) packages;

              packageTests = concatMapAttrs (
                packageName: package:
                mapAttrs' (testName: nameValuePair "${packageName}-${testName}") (package.tests or { })
              ) packages;
            in
            prefixAttrNames "package" (nonFunctionPackages // packageTests);

          devShells = prefixAttrNames "dev-shell";

          homeConfigurations =
            homeConfigurations:
            pipe homeConfigurations [
              (mapAttrs (_name: output: output.activationPackage))
              (prefixAttrNames "home-configuration")
            ];

          darwinConfigurations =
            darwinConfigurations:
            pipe darwinConfigurations [
              (mapAttrs (_name: output: output.system))
              (prefixAttrNames "darwin-configuration")
            ];
        };
      in
      outputs:
      pipe outputs [
        (concatMapAttrs (type: outputs: optionalAttrs (handlers ? ${type}) (handlers.${type} outputs)))
        (filterAttrs (name: _check: !hasPrefix "package-shell-bundle" name))
      ];
  in
  pipe root [
    (fileset.fileFilter (file: file.hasExt "nix"))
    fileset.toList
    (filter shouldMakeOutputs)
    (map makeOutputsForFile)
    (foldl' recursiveUpdate { })
    (
      outputs:
      outputs
      // rec {
        context = fullContext;
        checks = (makeAutoChecks outputs) // (outputs.checks or { });
        currentPlatformChecks = filterAttrs (_name: availableOn { inherit system; }) checks;
      }
    )
  ]
)
