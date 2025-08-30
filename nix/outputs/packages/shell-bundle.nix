{
  pkgs,
  outputs,
  ...
}:
let
  inherit (pkgs) runCommand closureInfo;

  shellBundle = outputs.bundlers.rootless outputs.packages.shell;
  shellBundleSize = "${closureInfo { rootPaths = [ shellBundle ]; }}/total-nar-size";
in
runCommand shellBundle.name { } ''
  function format {
    numfmt --to=iec --suffix=B $1
  }

  size=$(<${shellBundleSize})
  max_size=$((350 * 1024 * 1024))
  if (( size > max_size )); then
    echo "Error, shell is too big: $(format $size). Max size: $(format $max_size)" >&2
    exit 1
  else
    ln --symbolic ${shellBundle} $out
  fi
''
