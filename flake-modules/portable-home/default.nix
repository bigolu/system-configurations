{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
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
          shell = import ./make-portable-home {
            inherit pkgs self;
          };
        };
      };
    in
    optionalAttrs isSupportedSystem portableHomeOutputs;
}
