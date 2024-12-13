{
  inputs,
  ...
}:
{
  perSystem =
    # TODO: If I don't explicitly put pkgs here, it doesn't get included when I pass
    # `perSystemContext` to another function. To avoid having deadnix remove the
    # unused reference, I added a reference with `inherit`.
    perSystemContext@{
      lib,
      system,
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
          shell = import ./make-portable-home (
            perSystemContext
            // {
              inherit pkgs;
            }
          );
        };
      };
    in
    optionalAttrs isSupportedSystem portableHomeOutputs;
}
