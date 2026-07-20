{
  systemd = {
    services.nvidia-suspension-fix.serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/bin/env systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service";
      wantedBy = [ "multi-user.target" ];
    };
    # Sometimes after a system update, the nvidia services get disabled so we
    # have to reenable them.
    paths.nvidia-suspension-fix = {
      pathConfig.PathChanged = "/var/log/dpkg.log";
      wantedBy = [ "multi-user.target" ];
    };
  };
}
