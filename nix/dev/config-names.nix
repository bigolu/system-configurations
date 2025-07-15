let
  inherit (builtins) attrNames filter concatStringsSep;

  outputs = import ../../default.nix {};
  inherit (outputs.debug.lib) hasPrefix pipe mergeAttrsList;

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
