{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    attic.url = "github:zhaofengli/attic";

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
      nixos-generators,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
      ];

      secrets =
        let
          inherit (builtins) fromJSON readFile;
          inherit (nixpkgs) lib;
        in
        lib.genAttrs [
          "cachix"
          "cloudflare"
          "github"
          "minio"
          "passwords"
          "pubkeys"
          "wifi"
        ] (secretFile: fromJSON (readFile .secrets/${secretFile}.json));

      forAllSystems = inputs.nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
      ];
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
          default = pkgs.mkShellNoCC {
            shellHook = ''
              set -e

              ${lib.getExe pkgs.nixos-rebuild} switch \
                --fast --show-trace \
                --flake .#picache \
                --target-host "root@picache"

              ret="$?"

              [[ $ret -eq 0 ]] && exit 0
            '';
          };
        }
      );
    };
}
