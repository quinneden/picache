{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-shell-scripts.url = "github:quinneden/nix-shell-scripts";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      nixos-generators,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      secrets = builtins.fromJSON (builtins.readFile .secrets/common.json);
    in
    {
      packages = forEachSystem (system: {
        raspiImage = nixos-generators.nixosGenerate rec {
          system = "aarch64-linux";

          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.lix-module.overlays.default ];
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
          overlays = [ inputs.lix-module.overlays.default ];
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
                --target-host "root@10.0.0.101"
              exit 0
            '';
          };
        }
      );
    };
}
