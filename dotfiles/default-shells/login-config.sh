# shellcheck shell=sh
xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
export PYTHONPYCACHEPREFIX="$xdg_cache_home/python"
export MYPY_CACHE_DIR="$xdg_cache_home/mypy"
export RUFF_CACHE_DIR="$xdg_cache_home/ruff"
export GOPATH="$xdg_cache_home/go"
