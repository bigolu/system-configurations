let
  utils = import ../../../utils.nix;
in
{
  imports = with utils.modules.system; [
    (essentials {
      system = "x86_64-linux";
      hasGui = true;
      hostName = "comp_2";
    })
  ];
}
