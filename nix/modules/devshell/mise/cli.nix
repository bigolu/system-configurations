{ pkgs, ... }:
{
  devshell = {
    packages = with pkgs; [
      mise
      # For running tasks
      cached-nix-shell
    ];

    startup.mise.text = ''
      export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
      export CNS_NIXPKGS="$PRJ_ROOT/nix/packages.nix"
      # We include the dependencies for all nix shebang scripts in the development
      # devshell. Since we already make a GC root for the devshell, we don't need
      # GC roots for individual nix shebang scripts in a development devshell,
      # only CI.
      export CNS_GC_ROOT="''${CI:-}"
    '';
  };
}
