# This file is used with `nix-fast-build`. Alternatively, we could use
# `nix-fast-build --file default.nix -A currentPlatformChecks`, but that
# relies on the `--select` flag in `nix-eval-jobs`[1] and lix's fork of
# `nix-eval-jobs`[2] doesn't have that flag.
#
# [1]: https://github.com/NixOS/nix-eval-jobs/blob/ed28134795a4bf67ffe3d2d42858fcda93be8102/README.md?plain=1#L80
# [2]: https://git.lix.systems/lix-project/lix/src/branch/main/subprojects/nix-eval-jobs
(import ../default.nix { }).currentPlatformChecks
