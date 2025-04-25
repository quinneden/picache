{
  users = {
    groups.time-machine = { };
    users.time-machine = {
      isSystemUser = true;
      group = "time-machine";
      home = "/var/lib/time-machine";
    };
  };

  services = {
    avahi = {
      enable = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    samba = {
      enable = true;
      settings = {
        "Time Machine" = {
          path = "/var/lib/time-machine";
          "valid users" = "time-machine";
          public = "no";
          writeable = "yes";
          "force user" = "time-machine";
          "fruit:aapl" = "yes";
          "fruit:model" = "MacSamba";
          "fruit:time machine" = "yes";
          "readdir_attr:aapl_max_access" = "no";
          "vfs objects" = "catia fruit streams_xattr";
        };
      };
    };
  };
}
