let
  myUtils = import ../../../my-utils.nix;
in
{
  imports = with myUtils.modules.system; [
    (essentials {
      system = "x86_64-linux";
      hostName = "comp_2";
    })
  ];
}
