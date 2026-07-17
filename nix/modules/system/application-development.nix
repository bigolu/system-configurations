{ pkgs, lib, ... }:
let
  inherit (lib) genAttrs;
in
{
  # Required for rootless containers[1].
  #
  # [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
  security.wrappers = genAttrs [ "newuidmap" "newgidmap" ] (name: {
    setuid = true;
    owner = "root";
    group = "root";
    source = "${pkgs.shadow}/bin/${name}";
  });

  home-manager.users.biggs =
    { lib, config, ... }:
    let
      inherit (lib) hm;
    in
    {
      home.activation = {
        # Required for rootless containers[1].
        #
        # TODO: I want to use system-manager, but:
        #   - users.users.<name>.autoSubUidGidRange didn't work
        #   - I can't use environment.etc since /etc/sub{u,g}id can't be
        #     symlinks
        #
        # [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
        podman = hm.dag.entryAnywhere ''
          /usr/bin/sudo "${pkgs.shadow}/bin/usermod" \
            --add-subuids 100000-165535 \
            --add-subgids 100000-165535 \
            ${config.home.username}
        '';
      };
    };
}
