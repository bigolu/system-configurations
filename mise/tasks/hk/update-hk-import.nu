#nix --interpreter nu --packages nushell perl hk
#MISE hide=true

(
  perl
    -wsi
    -pe '
      $count += s{(v|hk@)[0-9]+\.[0-9]+\.[0-9]+}{$1$version}g;
      END { die "failed to substitute" if $count != 2 }
    '
    --
    $"-version=(hk version)"
    hk.pkl
)
