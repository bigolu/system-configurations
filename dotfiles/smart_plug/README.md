# Smart Plug Controller

This project contains:

- A script to turn a Kasa smart plug on and off.

- A daemon to automatically turn it on after the computer starts up or is woken
  up and turn it off before the computer suspends, hibernates, restarts, or
  shuts down. The daemon is created using [systemd][systemd] and
  [Hammerspoon][hammerspoon] for Linux and macOS respectively.

## Why

To avoid damage to self-powered speakers, you should always turn them on _after_
turning on the sound source (e.g. computer) and turn them off _before_ turning
off the sound source. By connecting my speakers to a smart plug, I can have this
project do it for me.

> TIP: If the speaker makes a POP noise when you connect/disconnect the sound
> source, then you probably turned the devices on/off in the wrong order.

## Requirements

- [Nix](https://nixos.org/) for dependencies. See the README at the root of this
  repository for installation instructions.
- Direnv to manage the development environment. You can install this with nix by
  running `nix profile install nixpkgs#direnv`.
- A Kasa smart plug

## Usage

- You can run it with
  `nix run github:bigolu/system-configurations#plugctl -- --help`.

## Development

- Enter the repository directory and run `direnv allow; nix-direnv-reload`. That
  will load all the dependencies.

[systemd]: https://systemd.io/
[hammerspoon]: https://www.hammerspoon.org/
