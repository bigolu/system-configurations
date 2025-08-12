{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) optionals optionalString;
in
{
  packages =
    with pkgs;
    optionals isLinux [
      # The full set of locales is pretty big (~220MB) so I'll only include the one
      # that will be used.
      (glibcLocales.override {
        allLocales = false;
        locales = [ "en_US.UTF-8/UTF-8" ];
      })
    ];

  shellHook = optionalString isLinux ''
    # This tells programs to use the locale we provided above
    export LC_ALL='en_US.UTF-8'
  '';
}
