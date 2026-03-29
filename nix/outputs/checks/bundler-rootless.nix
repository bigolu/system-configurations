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
  assertion = "Output of bundled hello matches unbundled hello";
  expected = runCommand "expected" { } ''
    ${hello} >$out
  '';
  actual = runCommand "actual" { } ''
    ${bundledHello} >$out
  '';
}
