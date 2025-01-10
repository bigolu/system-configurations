{ inputs, ... }:
final: prev:
let
  inherit (inputs.nixpkgs.lib) getExe recursiveUpdate;

  # TODO: I shouldn't have to do this. The programs should generate the files as part
  # of their build so they can be put in vendor_conf.d. See the direnv package for an
  # example of how this is done.
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

  # TODO: I shouldn't have to do this. The programs should generate the files as part
  # of their build so they can be put in vendor_conf.d. See the direnv package for an
  # example of how this is done.
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
