if test (count $argv) -eq 0
    treefmt --on-unmatched=fatal --no-cache
else
    # TODO: The output of `treefmt --help` says you can pass in multiple
    # paths, but it doesn't work
    for file in $argv
        treefmt --on-unmatched=fatal --no-cache "$file"
    end
end
