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
      ...
    }@inputs:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;

      secrets = builtins.fromJSON (builtins.readFile .secrets/common.json);
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
            inherit inputs secrets;
          };

          modules = [ ./configuration.nix ];

          format = "sd-aarch64";
        };
      });

      nixosConfigurations.picache = nixpkgs.lib.nixosSystem rec {
        system = "aarch64-linux";

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        specialArgs = {
          inherit inputs secrets;
        };

        modules = [
          ./configuration.nix
          ./modules
        ];
      };
    };
}
