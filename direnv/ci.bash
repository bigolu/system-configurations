# This way, any programs launched within the direnv environment will store their
# cache in the direnv layout directory. That entire directory will then be cached in
# CI, along with the Nix store. Examples of what will be in the cache:
#   - Any scripts direnv fetches when `source_url` is used e.g. nix-direnv
#   - nix-direnv's cache
#   - cached-nix-shell's cache
export XDG_CACHE_HOME="${direnv_layout_dir:-$PWD/.direnv}/xdg-cache-home"

export NIX_DEV_SHELL="${NIX_DEV_SHELL:-ci-essentials}"
source direnv/base.bash
