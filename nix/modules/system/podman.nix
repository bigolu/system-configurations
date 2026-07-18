# Required for rootless containers[1].
#
# [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md

{
  pkgs,
  lib,
  primaryUser,
  ...
}:
let
  inherit (lib) genAttrs genAttrs' nameValuePair;
in
{
  environment.systemPackages = with pkgs; [
    podman
    podman-compose
  ];

  security.wrappers = genAttrs [ "newuidmap" "newgidmap" ] (name: {
    setuid = true;
    owner = "root";
    group = "root";
    source = "${pkgs.shadow}/bin/${name}";
  });

  # Switch to using `users.users.<username>.autoSubUidGidRange` when
  # system-manager updates its copy of userborn to a version that contains this
  # commit:
  # https://github.com/nikstur/userborn/commit/cd5ea4954f3e24ba33a69e3c5e3c26d128301bbd
  systemd.tmpfiles.settings."10-podman-subids" = genAttrs' [ "subuid" "subgid" ] (
    name:
    nameValuePair "/etc/${name}" {
      "f+" = {
        mode = "0644";
        user = "root";
        group = "root";
        # For these files to be valid, all lines must end in a newline.
        argument = "${primaryUser}:100000:65536\\n";
      };
    }
  );
}
