{
  pkgs,
  lib,
  specialArgs,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (specialArgs) repositoryDirectory root;
in
{
  home.file = optionalAttrs isDarwin {
    ".hammerspoon/Spoons/EmmyLua.spoon" = {
      source = "${specialArgs.flakeInputs.spoons}/Source/EmmyLua.spoon";
      # I'm not symlinking the whole directory because EmmyLua is going to generate
      # lua-language-server annotations in there.
      recursive = true;
    };
  };

  # When switching generations, stop obsolete services and start ones that are wanted by active units.
  systemd = optionalAttrs isLinux {
    user.startServices = "sd-switch";
  };

  repository = {
    directory = repositoryDirectory;
    directoryPath = root;

    symlink = {
      baseDirectory = "${repositoryDirectory}/dotfiles";

      xdg = {
        executable =
          {
            "general" = {
              source = "general/bin";
              recursive = true;
            };
          }
          // lib.optionalAttrs isDarwin {
            "general macOS" = {
              source = "general/bin-macos";
              recursive = true;
            };
          };
      };
    };
  };
}
