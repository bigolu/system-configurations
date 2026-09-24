#nix --interpreter nu --packages nushell gh
#MISE hide=true

const tag = 'latest'

def main [] {
  delete_old_release
  make_new_release
}

def delete_old_release [] {
  gh release delete $tag --yes --cleanup-tag
}

def make_new_release [] {
  let checksum_file = mktemp --directory | path join checksums.txt
  glob assets/*
  # Match the format of `sha256sum` from coreutils since we tell users to use it to verify the checksums.
  | each {|file| $"($file | path basename)  ($file | hash sha256)"}
  | save --force $checksum_file

  (
		gh release create $tag
			--latest
			--title (date now | format date '%Y.%m.%d')
			--notes-file .github/release_notes.md
			assets/* $checksum_file
	)
}

def --wrapped gh [...args] {
  if $env.CI? == 'true' {
    ^gh ...$args
  } else {
    $"gh: ($args | str join ' ')"
  }
}
