{ inputs, ... }:
final: prev:
let
  xdgModule = import "${inputs.nix-xdg}/module.nix";
  # The intended way to use the nix-xdg is through a module, but I only want to use
  # the overlay so instead I call the module function here just to get the overlay
  # out.
  xdgModuleContents = xdgModule {
    pkgs = final;
    inherit (final) lib;
    config = { };
  };
  xdgOverlay = xdgModuleContents.config.lib.xdg.xdgOverlay {
    specs = {
      ripgrep.env.RIPGREP_CONFIG_PATH = { config }: "${config}/ripgreprc";
    };
  };
  xdgWrappers = xdgOverlay final prev;
in
{
  # I put these packages under 'xdgWrappers' so they don't overwrite the originals.
  # This is to avoid rebuilds of tools that depend on anything wrapped in this
  # overlay. This is fine since I only need XDG Base Directory compliance when I'm
  # using a program directly.
  inherit xdgWrappers;
}
