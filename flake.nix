{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-shell-scripts.url = "github:quinneden/nix-shell-scripts";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      nix-shell-scripts,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forEachSystem (system: {
        raspiImage = nixos-generators.nixosGenerate rec {
          system = "aarch64-linux";

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          specialArgs = {
            secrets = pkgs.toJSON (builtins.readFile .secrets/common.json);
          };

          modules = [
            ./configuration.nix
          ];

          format = "sd-aarch64";
        };
      });
    };
}
