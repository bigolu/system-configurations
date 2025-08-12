{ pkgs, ... }:
{
  packages = with pkgs; [
    fish
    # For nix's fish shell autocomplete
    (linkFarm "nix-share" { share = "${nix}/share"; })
  ];
}
