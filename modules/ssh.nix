{ secrets, ... }:
{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  programs.ssh = {
    knownHosts = {
      m4 = {
        hostNames = [ "10.0.0.90" ];
        publicKey = "${secrets.pubkeys.picache}";
      };
    };
  };

  users.users.qeden.openssh.authorizedKeys.keys = [ "${secrets.pubkeys.picache}" ];
}
