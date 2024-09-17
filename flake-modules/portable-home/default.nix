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

      portableHomeOutputs =
        let
          makePortableHome =
            {
              isGui,
              isMinimal,
            }:
            import ./make-portable-home {
              inherit
                pkgs
                self
                isGui
                isMinimal
                ;
            };

          makeShell =
            { isMinimal }:
            makePortableHome {
              isGui = false;
              inherit isMinimal;
            };
        in
        {
          packages = {
            shell = makeShell { isMinimal = false; };
            shellMinimal = makeShell { isMinimal = true; };
          };
        };
    in
    optionalAttrs isSupportedSystem portableHomeOutputs;
}
