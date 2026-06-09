{
  pkgs,
  perSystem,
  inputs,
  ...
}:
# SYNC: devshell-base
# All devshells should set `extraSpecialArgs`, `name`, and import `essentials.nix`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };

  configuration =
    { pkgs, ... }:
    let
      moduleRoot = ../../modules/devshell;
    in
    {
      imports = [
        (moduleRoot + "/essentials.nix")
        { devshell.name = "ci"; }
      ];

      extra.locale = {
        package = pkgs.glibcLocales.override {
          allLocales = false;
          locales = [ "en_US.UTF-8/UTF-8" ];
        };
      };

      # For the `run` steps in CI workflows
      devshell.packages = [ pkgs.bash ];

      gcRoot.roots.flake.exclude = [
        "llm-agents"
        "nix-gl-host-rs"
      ];
    };
}).shell
