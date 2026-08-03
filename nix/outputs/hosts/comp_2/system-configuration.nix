let
  modulesPath = ../../../modules/host;
in
{
  imports = [ (modulesPath + /essentials) ];
  nixpkgs.hostPlatform = "x86_64-linux";
}
