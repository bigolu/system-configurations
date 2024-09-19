set -o errexit
set -o nounset
set -o pipefail

cd ./flake-modules/bundler/gozip
go mod tidy
