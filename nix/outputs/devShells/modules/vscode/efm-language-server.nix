{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    efm-langserver
    # These get used in some of the commands in the efm-langserver config.
    bash
    jq
  ];
}
