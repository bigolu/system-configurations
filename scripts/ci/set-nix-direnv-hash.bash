#! /usr/bin/env cached-nix-shell
#! nix-shell -i shebang-runner
#! nix-shell --packages shebang-runner direnv
# ^ WARNING: Dependencies must be in this format to get parsed properly and added to
# dependencies.txt

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# WARNING: The following vs code bash debugger extension does not support
# bash_rematch: https://github.com/rogalmic/vscode-bash-debug/issues/183

nix_direnv_url_pattern='https://raw.githubusercontent.com/nix-community/nix-direnv/.*/direnvrc'
original_envrc="$(<.envrc)"
regex=".*(${nix_direnv_url_pattern}).*"
if ! [[ $original_envrc =~ $regex ]]; then
  echo 'Error: Could not find the nix-direnv URL' >&2
  exit 1
fi
nix_direnv_url="${BASH_REMATCH[1]}"

new_nix_direnv_hash="$(direnv fetchurl "$nix_direnv_url")"

# \\\\\n matches a backslash followed by a newline
separator=$'( |\\\\\n)'
quote=$'[\'"]'
nix_direnv_hash=$'[^\'"]+'
everything_before_nix_direnv_hash=".*source_url${separator}+${quote}${nix_direnv_url_pattern}${quote}${separator}+${quote}"
everything_after_nix_direnv_hash="${quote}.*"
replacement_regex="($everything_before_nix_direnv_hash)${nix_direnv_hash}($everything_after_nix_direnv_hash)"
if ! [[ $original_envrc =~ $replacement_regex ]]; then
  echo 'Error: Could not find the nix-direnv hash' >&2
  exit 1
fi
new_envrc="${BASH_REMATCH[1]}${new_nix_direnv_hash}${BASH_REMATCH[4]}"

echo "$new_envrc" >.envrc
