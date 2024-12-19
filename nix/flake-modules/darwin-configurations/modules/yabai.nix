{
  pkgs,
  ...
}:
let
  inherit (pkgs) symlinkJoin makeWrapper yabai;

  # all programs called from my yabairc
  dependencies = symlinkJoin {
    name = "yabai-dependencies";
    paths = with pkgs; [
      jq
      yabai
    ];
  };

  yabaiWithDependencies = symlinkJoin {
    name = "my-${yabai.name}";
    paths = [ yabai ];
    buildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/yabai \
      --prefix PATH : ${dependencies}/bin
    '';
  };
in
{
  services = {
    yabai = {
      enable = true;
      enableScriptingAddition = true;
      package = yabaiWithDependencies;
    };
  };
}
