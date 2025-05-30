# For development, create the file <project_root>/.envrc and add the following
# line:
#   source direnv/development.bash
#
# .envrc shouldn't be committed to version control so users can make changes to it
# without accidentally committing them. Here are some examples of changes they could
# make:
#   - Users may want to apply configuration specific to themselves. For example,
#     authentication tokens or shell aliases.
#   - Users can set environment variables that influence the behavior of the project
#     without accidentally committing those changes. For example, build flags.
#   - Users can add their configuration before the project's. This way, if there are
#     any environment variables that affect the behavior of the project's config,
#     users have a place to set them.
#   - Users can add their configuration after the project's. This way, they can
#     overwrite anything that doesn't work for them.
#   - If the project doesn't already provide a way to get its dependencies, users can
#     add configuration to get those dependencies using package managers like nix for
#     example.
#
# More reasons for not committing .envrc can be found in this GitHub issue[1].
#
# [1]: https://github.com/NixOS/nixpkgs/pull/325793#issuecomment-2219538799

NIX_DEV_SHELL="${NIX_DEV_SHELL:-development}" source direnv/base.bash
