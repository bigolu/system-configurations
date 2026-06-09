{ utils, ... }:
{
  nix-script.paths = [ (utils.projectRoot + /mise/tasks) ];
}
