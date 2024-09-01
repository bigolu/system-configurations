set -o errexit
set -o nounset
set -o pipefail

# If it's already installed then just exit.
if [ -x /usr/local/bin/brew ]; then
  exit
fi

# Install homebrew. Source: https://brew.sh/
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
