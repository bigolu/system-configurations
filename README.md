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
     --nix-package-url "https://releases.nixos.org/nix/nix-2.28.4/nix-2.28.4-$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]').tar.xz" \
     --extra-conf "extra-trusted-users = $(whoami)" \
     --no-confirm
   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

   nix shell \
     --override-flake nixpkgs github:NixOS/nixpkgs/cab778239e705082fe97bb4990e0d24c50924c04 \
     nixpkgs#git nixpkgs#direnv nixpkgs#bash nixpkgs#coreutils \
     --command bash --noprofile --norc -euc '
       git clone \
         https://github.com/bigolu/system-configurations.git \
         ~/code/system-configurations
       cd ~/code/system-configurations
       echo "source direnv.bash" >.envrc
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

[determinate-systems-installer-install]:
  https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#install-nix
[home-manager]: https://github.com/nix-community/home-manager
[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[releases]: https://github.com/bigolu/system-configurations/releases/latest
