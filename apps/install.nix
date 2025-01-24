{ inputs, pkgs, ... }:
let
  inherit (pkgs) lib writeShellApplication;
  inherit (inputs.nixos-anywhere.packages.${pkgs.system}) nixos-anywhere;
  inherit (inputs.nixos-images.packages.aarch64-linux) kexec-installer-nixos-unstable-noninteractive;

  kexecTarball =
    toString kexec-installer-nixos-unstable-noninteractive
    + "/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz";
in
with lib;
{
  type = "app";
  program = getExe (writeShellApplication {
    name = "picache-deploy";
    runtimeInputs = [ nixos-anywhere ];
    text = ''
      echo "THIS WILL ERASE ALL DATA!!!";
      echo "Continue? (enter x2)"
      read -r
      read -r

      nixos-anywhere -L \
        --kexec "${kexecTarball}" \
        --flake .#picache \
        --target-host root@picache
    '';
  });
}
