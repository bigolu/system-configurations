# shellcheck shell=sh

set -o errexit
set -o nounset

main() {
  fetcher="$(get_dependency curl wget)"
  case "$fetcher" in
  curl)
    curl() {
      command curl --proto '=https' -fL "$@"
    }
    file_exists() {
      curl -s --head "$1" 1>/dev/null 2>&1
    }
    download() {
      curl --progress-bar "$1" --output "$2"
    }
    ;;
  wget)
    wget() {
      command wget --https-only
    }
    file_exists() {
      wget -q --method=HEAD "$1"
    }
    download() {
      wget -O "$2" "$1"
    }
    ;;
  esac

  platform="$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')"
  release_artifact_name="$1-$platform"
  release_artifact_url="https://github.com/bigolu/system-configurations/releases/download/latest/$release_artifact_name"

  if ! file_exists "$release_artifact_url"; then
    abort "Your platform isn't supported: $platform"
  fi

  download "$release_artifact_url" "$release_artifact_name"
  chmod +x "$release_artifact_name"
  # The command in my README pipes this script into sh so we need to set stdin back to the terminal
  exec "./$release_artifact_name" </dev/tty
}

abort() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

get_dependency() {
  for command in "$@"; do
    if command -v "$command" 1>/dev/null 2>&1; then
      printf '%s' "$command"
      return
    fi
  done
  abort "Unable to find at least one of these commands: $*"
}

# This script gets piped into sh so we don't want to start doing anything until
# we know the whole script has been downloaded.
main "$@"
