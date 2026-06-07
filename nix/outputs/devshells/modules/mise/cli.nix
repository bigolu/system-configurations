{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    mise
    # For running file-based tasks
    cached-nix-shell
  ];

  env = [
    {
      name = "MISE_TRUSTED_CONFIG_PATHS";
      eval = "$PRJ_ROOT/mise/config.toml";
    }
    {
      name = "CNS_NIXPKGS";
      eval = "$PRJ_ROOT/nix/packages.nix";
    }
    # We include the dependencies for all nix shebang scripts in the development
    # devshell. Since we already make a GC root for the devshell, we don't need
    # GC roots for individual nix shebang scripts in a development devshell,
    # only CI.
    {
      name = "CNS_GC_ROOT";
      eval = "\${CI:-}";
    }
  ];
}
