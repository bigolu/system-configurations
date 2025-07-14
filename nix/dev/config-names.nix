let
  inherit (builtins) attrNames filter concatStringsSep;

  sources = import ../../../npins;
  lib = import "${sources.nixpkgs}/lib";
  inherit (lib) hasPrefix pipe mergeAttrsList;

  outputs = import ../../default.nix;

  configOutputKeys = [
    "homeConfigurations"
    "darwinConfigurations"
  ];
in
pipe configOutputKeys [
  (map (key: outputs.${key}))
  mergeAttrsList
  attrNames
  (filter (name: !hasPrefix "portable" name))
  (concatStringsSep "|")
]
