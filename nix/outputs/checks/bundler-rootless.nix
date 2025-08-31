{
  nixpkgs,
  lib,
  outputs,
  ...
}:
let
  inherit (lib) getExe;
  inherit (nixpkgs) runCommand;
  inherit (nixpkgs.testers) testEqualContents;

  hello = getExe nixpkgs.hello;
  bundledHello = outputs.bundlers.rootless nixpkgs.hello;
in
testEqualContents {
  assertion = "Bundled hello has the same output as unbundled hello";
  expected = runCommand "expected" { } ''
    ${hello} >$out
  '';
  actual = runCommand "actual" { } ''
    ${bundledHello} >$out
  '';
}
