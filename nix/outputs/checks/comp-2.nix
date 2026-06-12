{
  inputs,
  pkgs,
  ...
}:
let
  system = "x86_64-linux";
in
pkgs.lib.recursiveUpdate {
  meta.platforms = [ system ];
} inputs.self.legacyPackages.${system}.homeConfigurations."biggs@comp_2".activationPackage
