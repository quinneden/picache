{ inputs, ... }:
{
  networking = {
    hostName = "picache";
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = true;
      enabcm6e4ei0.useDHCP = true;
    };
    wireless = {
      enable = false;
      networks = {
        ${inputs.secrets.wifi.ssid}.psk = inputs.secrets.wifi.password;
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        139
        22
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
  };
}
