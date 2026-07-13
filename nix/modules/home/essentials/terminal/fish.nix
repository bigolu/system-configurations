{ pkgs, lib, ... }:
let
  inherit (lib) getExe hm;

  # Remove this override when this commit is included in a release:
  # https://github.com/fish-shell/fish-shell/commit/2c17c96e5535584f26ea2bcd5a2bebaf1feffdee
  fish = pkgs.fish.overrideAttrs {
    version = "4.8.0-next";
    doCheck = false;
    doInstallCheck = false;
    src = pkgs.fetchFromGitHub {
      owner = "fish-shell";
      repo = "fish-shell";
      rev = "2c17c96e5535584f26ea2bcd5a2bebaf1feffdee";
      hash = "sha256-KtpkSIO2P3oFB2fNDr10EkGI5lO5I6se2sVqiLVQDX8=";
    };
  };
in
{
  home = {
    packages = with pkgs.fishPlugins; [
      fish
      async-prompt
      direnv-shell-hooks
    ];

    activation.reloadFish = hm.dag.entryAfter [ "linkGeneration" ] ''
      ${getExe fish} -c fish-reload
    '';
  };

  fileWrapper.xdg.configFile."fish/conf.d" = {
    source = "fish/conf.d";
    recursive = true;
  };
}
