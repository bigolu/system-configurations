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
          activation = [
            "fzfSetup"
            "batSetup"
          ];
        };
      };
    };
}
