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
          "fruit:time machine" = "yes";
          "vfs objects" = "catia fruit streams_xattr";
        };
      };
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      139
      445
      548
      636
    ];
    allowedUDPPorts = [
      137
      138
    ];
    allowPing = true;
  };
}
