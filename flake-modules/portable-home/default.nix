{
  inputs,
  ...
}:
{
  perSystem =
    perSystemContext@{
      lib,
      system,
      # TODO: If I don't explicitly put pkgs here, it doesn't get included when I
      # pass `perSystemContext` to another function. Deadnix tries to to remove it
      # since it's unused so the pragma below prevents that. I should confirm that
      # this behavior is intended.
      #
      # deadnix: skip
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) optionalAttrs;

      isSupportedSystem =
        let
          supportedSystems = with inputs.flake-utils.lib.system; [
            x86_64-linux
            x86_64-darwin
          ];
        in
        builtins.elem system supportedSystems;

      portableHomeOutputs = {
        packages = {
          shell = import ./make-portable-home perSystemContext;
        };
      };
    in
    optionalAttrs isSupportedSystem portableHomeOutputs;
}
