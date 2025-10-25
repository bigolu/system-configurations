# This is a fork of devshell's locale module with the following changes.
#   - Added an enable option so you can unconditionally import it, but conditionally
#     use it.
#   - If `lang` is specified, only include the locale for it.

{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    literalMD
    mkIf
    ;

  cfg = config.locale;
in
{
  options.locale = {
    enable = mkEnableOption "locale support";

    lang = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Set the language for the project";
      example = "en_GB.UTF-8";
    };

    package = mkOption {
      type = types.package;
      description = "The glibc locale package that will be used on Linux";
      default =
        if cfg.lang == null then
          pkgs.glibcLocales
        else
          pkgs.glibcLocales.override {
            allLocales = false;
            locales = [ "${cfg.lang}/UTF-8" ];
          };
      defaultText = literalMD ''
        If `locale.lang` is `null`, then `pkgs.glibcLocales` will be used. If
        `locale.lang` is specified, then only the locale for that language will be
        included.
      '';
    };
  };

  config = mkIf cfg.enable {
    env =
      lib.optional pkgs.stdenv.isLinux {
        name = "LOCALE_ARCHIVE";
        value = "${cfg.package}/lib/locale/locale-archive";
      }
      ++ lib.optionals (cfg.lang != null) [
        {
          name = "LANG";
          value = cfg.lang;
        }
        {
          name = "LC_ALL";
          value = cfg.lang;
        }
      ];
  };
}
