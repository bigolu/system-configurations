rec {
  projectRoot = ../.;
  programConfigRoot = projectRoot + /program-configs;
  callIf = condition: function: if condition then function else (x: x);
}
