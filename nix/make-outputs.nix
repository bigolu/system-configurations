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
#         nested/
#           package3.nix
#   Outputs attrset:
#     {
#       homeConfigurations = <result of `import default.nix context`>;
#       packages = {
#         package1 = <result of `import package1.nix context`>;
#         package2 = <result of `import package2.nix context`>;
#         nested = {
#           package3 = <result of `import package3.nix context`>;
#         };
#       };
#       context;
#       checksForCurrentPlatform; (optional)
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
#     added to this set so outputs can refer to each other.
#   checksAttrPath (list[string]):
#     The list of keys, or path, for the attrset within the outputs attrset that
#     contains your checks. If this isn't empty, the key "checksForCurrentPlatform"
#     will be added to the outputs and will contain only the checks that support the
#     current platform. This is useful for running checks in CI.
#   system (string):
#     In flake pure evaluation mode, the current system can't be accessed so this
#     needs to be passed in.
#
# Return:
#   An attrset containing the outputs. The context will also be added to the
#   attrset since it can be useful to access it from outside of an output file. For
#   example, debugging in the REPL.
{
  root,
  context,
  lib,
  checksAttrPath ? [ "checks" ],
  system,
}:
let
  makeOutputs =
    self:
    let
      inherit (builtins)
        foldl'
        filter
        pathExists
        baseNameOf
        isFunction
        elem
        ;
      inherit (lib)
        pipe
        removePrefix
        fileset
        splitString
        recursiveUpdate
        setAttrByPath
        init
        last
        optionals
        removeSuffix
        filterAttrsRecursive
        getAttrFromPath
        ;

      context' = (if isFunction context then context context' else context) // {
        outputs = self;
      };

      makeOutputsForFile =
        file:
        let
          relativePath = removePrefix "${toString root}/" (toString file);
          parts = splitString "/" relativePath;
          basename = last parts;
          keys = (init parts) ++ optionals (basename != "default.nix") [ (removeSuffix ".nix" basename) ];
        in
        setAttrByPath keys (import file context');

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

      filterForCurrentPlatform =
        _name: package:
        # If there are no platforms, we assume it supports the current one.
        (package.meta.platforms or [ ]) == [ ] || elem system package.meta.platforms;
    in
    pipe root (
      [
        (fileset.fileFilter (file: file.hasExt "nix"))
        fileset.toList
        (filter shouldMakeOutputs)
        (map makeOutputsForFile)
        (foldl' recursiveUpdate { })
        (outputs: outputs // { context = context'; })
      ]
      ++ optionals (checksAttrPath != [ ]) [
        (
          outputs:
          outputs
          // {
            checksForCurrentPlatform = filterAttrsRecursive filterForCurrentPlatform (
              getAttrFromPath checksAttrPath outputs
            );
          }
        )
      ]
    );
in
lib.fix makeOutputs
