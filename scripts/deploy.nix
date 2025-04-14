{ nixos-rebuild-ng, writeShellApplication, ... }:

writeShellApplication {
  name = "deploy-picache";
  runtimeInputs = [ nixos-rebuild-ng ];
  text = ''
    nixos-rebuild-ng switch \
      --flake .#picache \
      --no-reexec \
      --show-trace \
      --sudo \
      --target-host "qeden@picache"
  '';
}
