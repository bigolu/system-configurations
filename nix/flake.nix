# This is only used for bundlers since the nix CLI only accepts a flakeref for
# `--bundler`.

{
  outputs =
    _:
    let
      # Everything below is vendored from https://github.com/numtide/flake-utils
      defaultSystems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      eachDefaultSystem = eachSystem defaultSystems;

      # Builds a map from <attr>=value to <attr>.<system>=value for each system.
      eachSystem = eachSystemOp (
        # Merge outputs for each system.
        f: attrs: system:
        let
          ret = f system;
        in
        builtins.foldl' (
          attrs: key:
          attrs
          // {
            ${key} = (attrs.${key} or { }) // {
              ${system} = ret.${key};
            };
          }
        ) attrs (builtins.attrNames ret)
      );

      # Applies a merge operation across systems.
      eachSystemOp =
        op: systems: f:
        builtins.foldl' (op f) { } (
          if !builtins ? currentSystem || builtins.elem builtins.currentSystem systems then
            systems
          else
            # Add the current system if the --impure flag is used.
            systems ++ [ builtins.currentSystem ]
        );
    in
    eachDefaultSystem (system: {
      bundlers = rec {
        inherit ((import ./default.nix { inherit system; }).bundlers) rootless;
        default = rootless;
      };
    });
}
