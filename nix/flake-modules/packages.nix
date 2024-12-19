{ self, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs) plugctl makePortableShell;
    in
    {
      packages = {
        default = plugctl;
        inherit plugctl;

        shell = makePortableShell {
          config = self.homeConfigurations."portable-home-${system}";
          shell = "fish";
          init = ''
            # Compile my custom themes for bat
            bat cache --build 1>/dev/null 2>&1
          '';
        };
      };
    };
}
