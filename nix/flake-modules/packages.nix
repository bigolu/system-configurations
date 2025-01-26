{
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      self',
      ...
    }:
    let
      inherit (pkgs) makePortableShell;
    in
    {
      packages = {
        default = self'.packages.shell;

        shell = makePortableShell {
          homeConfig = self.homeConfigurations."portable-home-${system}";
          shell = "fish";
          init = ''
            # Compile my custom themes for bat
            bat cache --build 1>/dev/null 2>&1
          '';
        };
      };
    };
}
