# Utilities for managing the system
#
# TODO: I should use system-manager instead of this module, but I don't think it can
# use Home Manager as a submodule[1].
#
# [1]: https://github.com/numtide/system-manager/issues/109
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    escapeShellArgs
    hm
    mkDefault
    foldl
    optionalAttrs
    mapAttrs
    attrValues
    ;
  inherit (pkgs.stdenv) isLinux;
in
{
  options.system = {
    file = mkOption {
      type = types.attrsOf (
        types.submodule (context: {
          options = {
            source = mkOption {
              type = types.path;
            };
            target = mkOption {
              type = types.str;
            };
          };
          config = {
            target = mkDefault context.config._module.args.name;
          };
        })
      );
      default = { };
    };
    systemd.units = mkOption {
      type = types.listOf types.path;
      default = [ ];
    };
    activation = mkOption {
      type = hm.types.dagOf types.str;
      default = { };
    };
  };

  config = {
    home.activation = mapAttrs (
      _: value:
      value
      // {
        data = ''
          # Add /usr/bin so scripts can access system programs like sudo/apt
          # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
          OLD_PATH="$PATH"
          PATH="$PATH:/usr/bin:/bin"
          ${value.data}
          PATH="$OLD_PATH"
        '';
      }
    ) config.system.activation;

    system.activation = {
      installSystemFiles =
        let
          group = if isLinux then "sudo" else "wheel";
        in
        hm.dag.entryAfter [ "writeBoundary" ] ''
          function install_file {
            local -r source="$1"
            local -r target="$2"
            sudo install \
              --compare -D --no-target-directory \
              --owner=root --group=${group} --mode='u=rwx,g=r,o=r' \
              "$source" "$target"
          }

          ${foldl (acc: next: ''
            ${acc}
            install_file ${
              escapeShellArgs [
                next.source
                next.target
              ]
            }
          '') "" (attrValues config.system.file)}
        '';
    }
    // optionalAttrs isLinux {
      installSystemUnits = hm.dag.entryAfter [ "writeBoundary" ] ''
        OLD_PATH="$PATH"
        PATH="$PATH:${pkgs.moreutils}/bin"

        function set_up_unit {
          unit_name="$1"
          unit_base_name="''${unit_name##*/}"

          if systemctl list-unit-files "$unit_base_name" 1>/dev/null 2>&1; then
            # This will unlink it
            chronic sudo systemctl disable "$unit_base_name"
          fi
          chronic sudo systemctl link "$unit_name"
          chronic sudo systemctl enable "$unit_base_name"

          # - If I don't this then `systemctl status <name>` shows that any timer
          #   set up here failed because it 'vanished'
          # - socket units need to be started
          extension="''${unit_base_name##*.}"
          if [[ $extension == 'timer' || $extension == 'socket' ]]; then
            chronic sudo systemctl start "$unit_base_name"
          fi
        }

        for unit in ${escapeShellArgs config.system.systemd.units}; do
          set_up_unit "$unit"
        done

        PATH="$OLD_PATH"
      '';
    };
  };
}
