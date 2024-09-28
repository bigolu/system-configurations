set -o errexit
set -o nounset
set -o pipefail

cd ./flake-modules/bundler/gozip
nix develop .#gomod2nix --command gomod2nix generate
