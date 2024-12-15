_: {
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages = {
        inherit (pkgs) plugctl;
        default = pkgs.plugctl;
      };
    };
}
