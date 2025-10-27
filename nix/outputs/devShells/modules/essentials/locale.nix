# This is a fork of devshell's locale module with the following changes.
#   - Added an enable option so you can unconditionally import it, but conditionally
#     use it.
#   - Support for only configuring the locale in CI.
#   - If `lang` is specified, only include the locale for it.

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
    ;
  inherit (pkgs.stdenv) isLinux;

  cfg = config.locale;
in
{
  options.locale = {
    enable = mkOption {
      type = types.either types.bool (types.enum [ "ci" ]);
      default = false;
      description = ''
        Whether to enable locale support. If set to `"ci"`, locale support will only
        be configured if the `CI` environment variable is set to `"true"`. This way,
        you can debug CI locally without changing the locale on the developer's
        machine.
      '';
    };

    language = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The language for the project";
      example = "en_GB.UTF-8";
    };

    package = mkOption {
      type = types.package;
      description = "The glibc locale package that will be used on Linux";
      default =
        if cfg.language == null then
          pkgs.glibcLocales
        else
          pkgs.glibcLocales.override {
            allLocales = false;
            locales = [ "${cfg.language}/UTF-8" ];
          };
      defaultText = literalMD ''
        If `locale.language` is `null`, then `pkgs.glibcLocales` will be used. If
        `locale.language` is specified, then only the locale for that language will
        be included.
      '';
    };
  };

  config = mkIf (cfg.enable == "ci" || cfg.enable) {
    devshell.startup.locale.text = ''
      if ${if (cfg.enable == "ci") then "[[ \${CI:-} == 'true' ]]" else "true"}; then
        ${optionalString isLinux ''
          export LOCALE_ARCHIVE=${cfg.package}/lib/locale/locale-archive
        ''}
        ${optionalString (cfg.language != null) ''
          export LANG=${escapeShellArg cfg.language}
          export LC_ALL="$LANG"
        ''}
      fi
    '';
  };
}
