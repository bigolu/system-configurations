{
  _class,
  pkgs,
  primaryUser,
  ...
}:
{
  darwin =
    let
      inherit (pkgs) symlinkJoin makeWrapper yabai;

      # all programs called from my yabairc
      dependencies = symlinkJoin {
        name = "yabai-dependencies";
        paths = with pkgs; [
          jq
          yabai
          bash
        ];
      };

      yabaiWithDependencies = symlinkJoin {
        name = "my-${yabai.name}";
        paths = [ yabai ];
        nativeBuildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/yabai \
          --prefix PATH : ${dependencies}/bin
        '';
      };
    in
    {
      home-manager.users.${primaryUser}.fileWrapper.xdg.configFile."yabai/yabairc".source =
        "yabai/yabairc.bash";

      services.yabai = {
        enable = true;
        enableScriptingAddition = true;
        package = yabaiWithDependencies;
      };
    };
}
.${toString _class}
