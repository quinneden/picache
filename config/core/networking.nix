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
      enable = true;
      networks = {
        ${inputs.secrets.wifi.ssid}.psk = inputs.secrets.wifi.password;
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };
}
