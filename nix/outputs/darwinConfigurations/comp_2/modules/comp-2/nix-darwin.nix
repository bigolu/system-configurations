{
  homeDirectory,
  username,
  config,
  ...
}:
{
  configureLoginShellForNixDarwin = true;
  users.users.${username}.home = homeDirectory;

  system = {
    stateVersion = 4;

    activationScripts.postActivation.text = ''
      sudo nix-env --profile ${config.system.profile} --delete-generations old
    '';
  };
}
