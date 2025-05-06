{ self, ... }:
{
  flake.overlays.default = self.overlays.misc;
  flake.overlays.misc = import ../../public-overlay;
}
