{ pubkeys, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  programs.ssh = {
    knownHosts = {
      macmini-m4 = {
        hostNames = [ "10.0.0.53" ];
        publicKey = pubkeys.macmini-m4;
      };
    };
  };

  users.users = {
    root.openssh.authorizedKeys.keys = [
      pubkeys."quinn@macmini-m4"
    ];
    qeden.openssh.authorizedKeys.keys = [
      pubkeys."quinn@macmini-m4"
    ];
  };
}
