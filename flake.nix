# This is only used for bundlers since the nix CLI only accepts a flakeref for
# `--bundler`.
{
  outputs =
    _:
    let
      # Everything below was taken from https://github.com/numtide/flake-utils

      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

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
      ) systems;

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
    eachSystem (system: {
      bundlers = rec {
        inherit ((import ./. { inherit system; }).bundlers) rootless;
        default = rootless;
      };
    });
}
