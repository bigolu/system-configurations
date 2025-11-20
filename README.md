# System Configurations

This repository holds the [Home Manager][home-manager] and
[nix-darwin][nix-darwin] configurations for my machines. I don't expect anyone
else to use this, but I figured I'd leave the repo public as a resource for
people who want to manage their systems similarly.

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Initializing a Configuration](#initializing-a-configuration)
- [Running the Portable Configuration](#running-the-portable-configuration)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Initializing a Configuration

1. In the last command below, replace `REPLACE_ME` with the name of the config
   to apply. Valid config names are: `comp_1` `comp_2`. Then run the commands
   which will install Nix and initialize the config.

   > NOTE: The [Lix installer][lix-installer] may have changed since this was
   > written so make sure the installation command below is still valid.

   ```bash
   curl -sSf -L https://install.lix.systems/lix |
     sh -s -- install \
       --nix-package-url "https://releases.lix.systems/lix/lix-2.93.3/lix-2.93.3-$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]').tar.xz" \
       --extra-conf "extra-trusted-users = $(whoami)" \
       --no-confirm &&
     "$SHELL" -lc '"$@"' -- \
       nix run github:bigolu/system-configurations -- REPLACE_ME
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

     2. Open Hammerspoon and Nightfall to configure them.

## Running the Portable Configuration

You can also run a shell with a Home Manager configuration loaded into it. This
is helpful when you only need to use the configuration temporarily and not apply
it, like when you're on a remote host or in a container. You can download it
from the [releases page][releases].

[lix-installer]: https://lix.systems/install/
[home-manager]: https://github.com/nix-community/home-manager
[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[releases]: https://github.com/bigolu/system-configurations/releases/latest
