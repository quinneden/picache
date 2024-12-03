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

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
        in
        {
          default = pkgs.mkShell {
            shellHook = ''
              set -e
              ${lib.getExe pkgs.nixos-rebuild} switch \
                --fast --show-trace \
                --flake .#picache \
                --target-host "root@10.0.0.101" \
                --build-host "root@10.0.0.101"
              exit 0
            '';
          };
        }
      );
    };
}
