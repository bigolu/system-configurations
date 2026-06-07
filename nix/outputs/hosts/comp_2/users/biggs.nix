_:
let
  moduleRoot = ../../../../modules/home;
in
{
  imports = [
    # This should be added to every Home Manager configuration
    # SYNC: hm-base
    {
      imports = [ (moduleRoot + "/essentials") ];
      _module.args = {
        hasGui = true;
        hostName = "comp_3";
      };
    }

    (moduleRoot + "/application-development")
    (moduleRoot + "/speakers.nix")
  ];
}
