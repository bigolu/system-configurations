_:
let
  moduleRoot = ../../../../home-modules;
in
{
  imports = [
    # This should be added to every Home Manager configuration.
    # SYNC: hm-base
    {
      imports = [ (moduleRoot + "/common") ];
      _module.args = {
        hasGui = true;
        hostName = "comp_1";
      };
    }

    (moduleRoot + "/application-development")
    (moduleRoot + "/speakers.nix")
    (moduleRoot + "/comp-1.nix")
  ];
}
