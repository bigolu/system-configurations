{
  projectRoot = ../.;
  callIf = condition: function: if condition then function else (x: x);
}
