{
  environment = {
    pathsToLink = [ "/share" ];
    extraInit = ''
      export XDG_DATA_DIRS="/run/system-manager/sw/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

      user_share_dir="/etc/profiles/per-user/$USER/share"
      if [ -d "$user_share_dir" ]; then
        export XDG_DATA_DIRS="$user_share_dir''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      fi
    '';
  };
}
