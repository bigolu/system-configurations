{
  imports = map (path: ../../../modules/host + path) [ /essentials ];
  nixpkgs.hostPlatform = "x86_64-linux";
}
