{
  pkgs,
  lib,
  outputs,
  system,
  ...
}:
let
  inherit (builtins) getAttr elem;
  inherit (lib)
    mapAttrs
    mapAttrs'
    nameValuePair
    pipe
    mergeAttrsList
    getExe
    filterAttrs
    ;

  prefixAttrNames = prefix: mapAttrs' (name: nameValuePair "${prefix}-${name}");

  filterPlatforms = filterAttrs (
    _name: package: (package.meta.platforms or [ ]) == [ ] || elem system package.meta.platforms
  );

  darwinChecks = pipe outputs.darwinConfigurations [
    (mapAttrs (_name: getAttr "system"))
    (prefixAttrNames "darwin")
  ];

  devShellChecks = pipe outputs.devShells [
    (prefixAttrNames "dev-shell")
  ];

  homeChecks = pipe outputs.homeConfigurations [
    (mapAttrs (_name: getAttr "activationPackage"))
    (prefixAttrNames "home")
  ];

  packageChecks = pipe outputs.packages [
    (prefixAttrNames "package")
  ];

  bundlerChecks =
    let
      bundlerPrefix = "bundler";

      rootlessBundlerName = "rootless";
      rootlessBundler = outputs.bundlers.${rootlessBundlerName};
      # TODO: To ensure the bundle isn't accessing the nix store I should use
      # something like chroot.
      rootlessBundlerCheck = pkgs.runCommand "check-${bundlerPrefix}-${rootlessBundlerName}" { } ''
        [[ $(${rootlessBundler pkgs.hello}) == $(${getExe pkgs.hello}) ]]

        # Nix only considers the command to be successful if something is written
        # to $out.
        echo success > $out
      '';
    in
    prefixAttrNames bundlerPrefix {
      ${rootlessBundlerName} = rootlessBundlerCheck;
    };
in
pipe
  [
    darwinChecks
    devShellChecks
    homeChecks
    packageChecks
    bundlerChecks
  ]
  [
    mergeAttrsList
    filterPlatforms
  ]
