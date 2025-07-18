{ nixpkgs }:
builtins.mapAttrs
  # Use nixpkgs' derivation-based fetchers for all pins except nixpkgs channels.
  (_name: pin: if pin.type == "Channel" then pin else pin { pkgs = nixpkgs; })
  (import ../npins)
