{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "deploy";
  runtimeInputs = [ pkgs.nixos-rebuild-ng ];
  text = ''
    nixos-rebuild-ng switch \
      --no-reexec \
      --flake .#picache \
      --show-trace \
      --target-host "root@picache"
  '';
}
