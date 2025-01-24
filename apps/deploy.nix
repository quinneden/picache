{ pkgs, ... }:
let
  inherit (pkgs) lib writeShellApplication;
in
with lib;
{
  type = "app";
  program = getExe (writeShellApplication {
    name = "picache-deploy";
    runtimeInputs = with pkgs; [ nixos-rebuild ];
    text = ''
      nixos-rebuild switch --fast --show-trace \
        --target-host "root@picache" \
        --flake .#picache
    '';
  });
}
