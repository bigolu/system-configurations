_:
let
  generateChecksModules = import ./generate-checks.nix;
in
{
  imports = [
    # I import these modules directly instead of referencing self.flakeModules.<name>
    # to avoid infinite recursion.
    generateChecksModules
  ];

  flake.flakeModules = {
    generate-checks = generateChecksModules;
    default = generateChecksModules;
  };
}
