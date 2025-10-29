# This is a fork of devshell's locale module with the following changes.
#   - Added an enable option so you can unconditionally import it, but conditionally
#     use it. This way, you don't need to use a conditional import which often causes
#     infinite recursion.
#   - Support for only configuring the locale in CI.
#   - If `locale` is specified, only include that locale.

{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    literalMD
    mkIf
    escapeShellArg
    optionalString
    elemAt
    splitString
    ;
  inherit (pkgs.stdenv) isLinux;

  cfg = config.locale;
  # Example: "en_NG/UTF-8" -> "en_NG"
  localeWithoutCharEncoding = elemAt (splitString "/" cfg.locale) 0;
in
{
  options.locale = {
    enable = mkOption {
      type = types.either types.bool (types.enum [ "ci" ]);
      default = "ci";
      description = ''
        Whether to enable locale support. Doing so can help to [avoid locale-related issues on non-NixOS linux distributions](https://wiki.nixos.org/wiki/Locales#Troubleshooting_when_using_nix_on_non-NixOS_linux_distributions).
        If set to `"ci"`, locale support will only be configured if the `CI`
        environment variable is set to `"true"`. This way, you can debug CI
        locally without changing your locale.
      '';
    };

    locale = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The locale to use";
      example = "en_NG/UTF-8";
    };

    package = mkOption {
      type = types.package;
      description = "The glibc locale package that will be used on Linux";
      default =
        if cfg.locale == null then
          pkgs.glibcLocales
        else
          pkgs.glibcLocales.override {
            allLocales = false;
            locales = [ cfg.locale ];
          };
      defaultText = literalMD ''
        If `locale.locale` is `null`, then `pkgs.glibcLocales` will be used. If
        `locale.locale` is not `null`, then only that locale from `pkgs.glibcLocales`
        will be included. [Locales supported by `pkgs.glibcLocales`](https://sourceware.org/git/?p=glibc.git;a=blob;f=localedata/SUPPORTED).
      '';
    };
  };

  config = mkIf (cfg.enable == "ci" || cfg.enable) {
    devshell.startup.locale.text = ''
      if ${if (cfg.enable == "ci") then "[[ \${CI:-} == 'true' ]]" else "true"}; then
        ${optionalString isLinux ''
          export LOCALE_ARCHIVE=${cfg.package}/lib/locale/locale-archive
        ''}
        ${optionalString (cfg.locale != null) ''
          # https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html#Locale-Environment-Variables-1
          export LC_ALL=${escapeShellArg localeWithoutCharEncoding}
        ''}
      fi
    '';
  };
}
