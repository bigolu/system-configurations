{ self, ... }:
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
    default = self.flakeModules.generate-checks;
    generate-checks = generateChecksModules;
  };
}
