# System Configurations

This repository holds the [Home Manager][home-manager] and
[nix-darwin][nix-darwin] configurations for my machines. I don't expect anyone
else to use this, but I figured I'd leave the repo public as a resource for
people who want to manage their systems similarly.

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Applying a Configuration](#applying-a-configuration)
- [Running the Portable Configuration](#running-the-portable-configuration)
  - [How it Works](#how-it-works)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Applying a Configuration

1. In the last command below, replace `<comp_1|comp_2>` with only the name of
   the config to apply. Then run the commands which will install Nix, clone the
   repo, and apply the config. Instead of using the `curl` command below, you
   can also download this Nix installer from [their
   site][determinate-systems-installer-install].

   > NOTE: The installer may have changed since this was written so make sure
   > the installation command below is still valid.

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
     sh -s -- install \
     --nix-package-url "https://releases.nixos.org/nix/nix-2.28.3/nix-2.28.3-$(uname -ms | tr ' [:upper:]' '-[:lower:]').tar.xz" \
     --extra-conf "extra-trusted-users = $(whoami)" \
     --no-confirm
   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

   nix shell \
     --override-flake nixpkgs github:NixOS/nixpkgs/69dfebb3d175bde602f612915c5576a41b18486b \
     nixpkgs#git nixpkgs#direnv nixpkgs#bash nixpkgs#coreutils \
     --command bash --noprofile --norc -euc '
       git clone \
         https://github.com/bigolu/system-configurations.git \
         ~/code/system-configurations
       cd ~/code/system-configurations
       echo "source direnv/config/development.bash" >.envrc
       direnv allow
       direnv exec . mise run system:init <comp_1|comp_2>
     '
   ```

2. Post-Install steps:

   - Linux

     1. Logout and login so the login shell configuration can get applied.

   - macOS

     1. Keyboard:

        - Set the keyboard input source to 'Others → (No Accent Keys)'.

        <!--
          TODO: I can automate shortcuts when this issue gets resolved:
          https://github.com/nix-darwin/nix-darwin/issues/185
        -->

        - Shortcuts:

          - Disable: "Select the previous input source" `ctrl+space`,
            "Application windows" `ctrl+↓`

          - Change: "Mission Control → Move left/right a space" to `cmd+[` and
            `cmd+]` respectively, "Mission Control" to `cmd+d`, "Mission Control
            → Switch to Desktop 1-9" `cmd+[1-9]`

     2. Open Hammerspoon, MonitorControl, UnnaturalScrollWheels, Nightfall, and
        Mac Mouse Fix to configure them.

## Running the Portable Configuration

You can also run a shell with a Home Manager configuration loaded into it. This
is helpful when you only need to use the configuration temporarily and not apply
it, like when you're on a remote host or in a container. You can download it
from the [releases page][releases].

### How it Works

A nix bundler takes a [Home Manager][home-manager] configuration and bundles all
of its dependencies, and the bundler itself, into a self-extracting archive
(SEA). When you execute the SEA, it unpacks the dependencies and rewrites any
paths referenced in a file that start with `/nix/store`. It rewrites these paths
to a symbolic link that it creates in `/tmp` with the same number of characters
(e.g. `/tmp/abcde`). It's important that the length of the new path be the same
as the length of `/nix/store`. This is because binaries usually read these paths
using offsets and so a longer/shorter path would change these offsets. The
symbolic link then points to the extracted contents of the SEA which is stored
in the system's temporary directory. This could also be `/tmp` or the path
pointed to by the environment variable `$TMPDIR`, if it's set. I found this idea
in a [GitHub issue comment regarding a "rootless Nix"][rootless-nix] and decided
to build it to learn more about Nix.

[determinate-systems-installer-install]:
  https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#install-nix
[home-manager]: https://github.com/nix-community/home-manager
[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[rootless-nix]: https://github.com/NixOS/nix/issues/1971#issue-304578884
[releases]: https://github.com/bigolu/system-configurations/releases/latest
