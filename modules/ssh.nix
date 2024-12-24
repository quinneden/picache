{ secrets, ... }:
{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  programs.ssh = {
    knownHosts = {
      macmini-m4 = {
        hostNames = [ "10.0.0.39" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCHB5JZ8gQ3FFXnh2LMOkQZl1l/Ao6Er7hE5joFq45B";
      };
    };
  };

  users.users.qeden.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCHB5JZ8gQ3FFXnh2LMOkQZl1l/Ao6Er7hE5joFq45B"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJyLtibXqcDXRQ8DzDUbVw71YA+k+L7fH7H3oPYyjFII"
  ];
}
