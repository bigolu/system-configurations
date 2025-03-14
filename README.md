# System Configurations

This repository holds the [Home Manager][home-manager] and
[nix-darwin][nix-darwin] configurations for my machines. I don't expect anyone
else to use this, but I figured I'd leave the repo public as a resource for
people who want to manage their systems similarly.

## Table of Contents

<!--
  DO NOT EDIT THE TABLE OF CONTENTS MANUALLY.
  It gets generated by doctoc:
  https://github.com/thlorenz/doctoc
  To regenerate, run `mise run check generate`. Though the pre-commit hook will
  automatically run this for you.
-->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Applying a Configuration](#applying-a-configuration)
  - [Configs](#configs)
  - [Steps](#steps)
- [Running the Portable Home Configuration](#running-the-portable-home-configuration)
  - [How it Works](#how-it-works)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Applying a Configuration

### Configs

For reference, here are all the configs, grouped by system manager, in the
format "\<config_name> / \<platform>":

<!-- START_CONFIGURATIONS -->

- Home Manager

  - linux / x86_64-linux

- nix-darwin

  - mac / x86_64-darwin

<!-- END_CONFIGURATIONS -->

### Steps

1. Install Nix using [Determinate Systems Nix
   Installer][determinate-systems-installer]. You can use the `curl` command
   below or download it from [the site][determinate-systems-installer-install].
   After you download it, replace the platform (x86_64) in the URL below with
   that of your system and then run the command:

   > NOTE: The installer may have changed since this was written so make sure
   > everything below is still valid.

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
     sh -s -- install \
     --nix-package-url https://releases.nixos.org/nix/nix-2.24.12/nix-2.24.12-x86_64-linux.tar.xz \
     --extra-conf "extra-trusted-users = $(whoami)"
   ```

2. Run the following command to get the repo, load the environment, and start
   `fish`.

   ```bash
   # Fish does not have a way to exit whenever a command fails so I am
   # manually adding `|| exit`.
   # https://github.com/fish-shell/fish-shell/issues/510
   #
   # NOTE: Comments can't go inside the command string because they would end the
   # string.
   nix shell \
     --override-flake nixpkgs github:NixOS/nixpkgs/02032da4af073d0f6110540c8677f16d4be0117f \
     nixpkgs#fish nixpkgs#gitMinimal nixpkgs#direnv nixpkgs#bash nixpkgs#coreutils \
     --command fish --no-config --init-command '
       git clone \
         https://github.com/bigolu/system-configurations.git \
         ~/code/system-configurations || exit
       cd ~/code/system-configurations || exit
       direnv hook fish | source || exit
       cp direnv/local.bash .envrc || exit
       direnv allow || exit
     '
   ```

3. The next steps depend on the operating system you're using:

   - Linux

     1. Apply a Home Manager configuration by running
        `mise run system-init home-manager <config_name>` where `<config_name>`
        is any compatible config from the [config list](#configs).

   - macOS

     1. Apply a nix-darwin configuration by running
        `mise run system-init nix-darwin <config_name>` where `<config_name>` is
        any compatible config from the [config list](#configs).

     2. Keyboard:

        - Set the keyboard input source to 'Others → (No Accent Keys)'.

        <!--
          TODO: I can automate shortcuts when this issue gets resolved:
          https://github.com/LnL7/nix-darwin/issues/185
        -->

        - Shortcuts:

          - Disable: "Select the previous input source" `ctrl+space`,
            "Application windows" `ctrl+↓`

          - Change: "Mission Control → Move left/right a space" to `cmd+[` and
            `cmd+]` respectively, "Mission Control" to `cmd+d`, "Mission Control
            → Switch to Desktop 1-9" `cmd+[1-9]`

     3. Open Hammerspoon, Finicky, MonitorControl, UnnaturalScrollWheels,
        Nightfall, Mac Mouse Fix, and Podman Desktop to configure them.

## Running the Portable Home Configuration

You can also run a shell with a home configuration already loaded in it. This is
helpful when you only need to use the configuration temporarily and not apply
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

[determinate-systems-installer]:
  https://github.com/DeterminateSystems/nix-installer
[determinate-systems-installer-install]:
  https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#install-nix
[home-manager]: https://github.com/nix-community/home-manager
[nix-darwin]: https://github.com/LnL7/nix-darwin
[rootless-nix]: https://github.com/NixOS/nix/issues/1971#issue-304578884
[releases]: https://github.com/bigolu/system-configurations/releases/latest
