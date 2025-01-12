{ inputs, ... }:
final: prev:
let
  inherit (inputs.nixpkgs.lib) getExe recursiveUpdate;

  # TODO: I shouldn't have to do this. Either nixpkgs should add the completion
  # files, as they do with lefthook[1], or the tool itself should generate the files
  # as part of its build script, as direnv does[2].
  #
  # [1]: https://github.com/NixOS/nixpkgs/blob/cd7ab3a2bc59a881859a901ba1fa5e7ddf002e5e/pkgs/by-name/le/lefthook/package.nix
  # [2]: https://github.com/direnv/direnv/blob/29df55713c253e3da14b733da283f03485285cea/GNUmakefile
  zoxideWithFishConfig =
    let
      oldZoxide = prev.zoxide;

      fishConfig =
        (final.runCommand "zoxide-fish-config-${oldZoxide.version}" { } ''
          config_directory="$out/share/fish/vendor_conf.d"
          mkdir -p "$config_directory"
          ${getExe oldZoxide} init --no-cmd fish > "$config_directory/zoxide.fish"
        '')
        // {
          inherit (oldZoxide) version;
        };

      newZoxide = final.symlinkJoin {
        inherit (oldZoxide) pname version;
        paths = [
          oldZoxide
          fishConfig
        ];
      };
    in
    # Merge with the original package to retain attributes like meta
    recursiveUpdate oldZoxide newZoxide;

  # TODO: I shouldn't have to do this. Either nixpkgs should add the completion
  # files, as they do with lefthook[1], or the tool itself should generate the files
  # as part of its build script, as direnv does[2].
  #
  # [1]: https://github.com/NixOS/nixpkgs/blob/cd7ab3a2bc59a881859a901ba1fa5e7ddf002e5e/pkgs/by-name/le/lefthook/package.nix
  # [2]: https://github.com/direnv/direnv/blob/29df55713c253e3da14b733da283f03485285cea/GNUmakefile
  brootWithFishConfig =
    let
      oldBroot = prev.broot;

      fishConfig =
        (final.runCommand "broot-fish-config-${oldBroot.version}" { } ''
          config_directory="$out/share/fish/vendor_conf.d"
          mkdir -p "$config_directory"
          ${getExe oldBroot} --print-shell-function fish > "$config_directory/broot.fish"
        '')
        // {
          inherit (oldBroot) version;
        };

      newBroot = final.symlinkJoin {
        inherit (oldBroot) pname version;
        paths = [
          oldBroot
          fishConfig
        ];
      };
    in
    # Merge with the original package to retain attributes like meta
    recursiveUpdate oldBroot newBroot;
in
{
  zoxide = zoxideWithFishConfig;
  broot = brootWithFishConfig;
}
