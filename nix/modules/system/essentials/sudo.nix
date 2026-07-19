# I want to run `darwin-rebuild/system-manager/home-manager switch` and only
# input my password once, but homebrew, rightly, invalidates the sudo cache
# before it runs[1] so I have to input my password again for subsequent steps in
# the rebuild. This script allows ANY command to be run without a password, for
# the duration of the specified command. It also runs the specified command as
# the user that launched this script, i.e. SUDO_USER, and not root.
#
# [1]: https://github.com/Homebrew/brew/pull/17694/commits/2adf25dcaf8d8c66124c5b76b8a41ae228a7bb02

{ pkgs, lib, ... }:
let
  inherit (pkgs) writeText;
  inherit (lib) getExe;

  # On macOS, "admin" should be used instead of sudo.
  sudoersFile = writeText "10-bigolu" ''
    %sudo ALL=(ALL:ALL) NOPASSWD: ${getExe pkgs.run-as-admin}
    Defaults  env_keep += "TERMINFO"
    Defaults  env_keep += "PATH"
    Defaults  timestamp_timeout=30
  '';
in
{
  environment = {
    systemPackages = [ pkgs.run-as-admin ];
    etc."sudoers.d/10-bigolu".source = sudoersFile;
  };
}
