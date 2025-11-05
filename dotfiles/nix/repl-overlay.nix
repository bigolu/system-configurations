_info: _final: _prev:
rec {
  pkgs = import <nixpkgs> { };
  inherit (pkgs) lib;
}
// builtins
