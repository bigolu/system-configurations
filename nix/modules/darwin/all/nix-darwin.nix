{ homeDirectory, username, ... }: {
  configureLoginShellForNixDarwin = true;
  users.users.${username}.home = homeDirectory;
  system.stateVersion = 4;
}
