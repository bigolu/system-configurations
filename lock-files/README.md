# Lock files

When an `hk` hook is run with `fix=true`, steps won't be parallelized if their
globs intersect, or if they don't specify globs, even if they only contain
`check` commands. To work around this, I set a glob containing a single file
from this directory, guaranteeing that they won't intersect.
