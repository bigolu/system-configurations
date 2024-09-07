readarray -d '' scripts < <(fd --print0 --hidden --extension bash --extension sh)
shellcheck "$@" "${scripts[@]}"
