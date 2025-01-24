let
  pubkeys = {
    macMini = {
      host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCHB5JZ8gQ3FFXnh2LMOkQZl1l/Ao6Er7hE5joFq45B";
      user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJyLtibXqcDXRQ8DzDUbVw71YA+k+L7fH7H3oPYyjFII";
    };
  };
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "prohibit-password";
    };
  };

  programs.ssh = {
    knownHosts = {
      macmini-m4 = {
        hostNames = [ "10.0.0.53" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJyLtibXqcDXRQ8DzDUbVw71YA+k+L7fH7H3oPYyjFII";
      };
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    pubkeys.macMini.host
    pubkeys.macMini.user
  ];

  users.users.qeden.openssh.authorizedKeys.keys = [
    pubkeys.macMini.host
    pubkeys.macMini.user
  ];
}
