{
  nixpkgs,
  lib,
  outputs,
  name,
  ...
}:
let
  hello = lib.getExe nixpkgs.hello;
  bundledHello = outputs.bundlers.rootless nixpkgs.hello;
in
nixpkgs.runCommand name { } ''
  [[ $(${bundledHello}) == $(${hello}) ]]

  # Nix only considers the command to be successful if something is written
  # to $out.
  echo success > $out
''
