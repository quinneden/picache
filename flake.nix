{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      lix-module,
      nixpkgs,
      raspberry-pi-nix,
      self,
      ...
    }@inputs:
    let
      inherit (nixpkgs.lib) genAttrs nixosSystem;

      forEachSystem =
        function:
        genAttrs
          [
            "aarch64-darwin"
            "aarch64-linux"
          ]
          (
            system:
            function {
              pkgs = import nixpkgs {
                inherit system;
                config.allowUnfree = true;
              };
            }
          );

      secrets =
        let
          inherit (builtins) fromJSON readFile;
        in
        genAttrs [
          "cachix"
          "cloudflare"
          "github"
          "passwords"
          "pubkeys"
          "wifi"
        ] (secretFile: fromJSON (readFile .secrets/${secretFile}.json));
    in
    {
      nixosModules = rec {
        default = ext4-image;
        ext4-image = ./nixosModules/ext4-image;
        btrfs-image = ./nixosModules/btrfs-image;
      };

      packages = forEachSystem (
        { pkgs }:
        {
          image =
            let
              inherit (self.nixosConfigurations.picache.config.system.build) sdImage;
            in
            sdImage.overrideAttrs {
              compressImage = false;
              rootPartitionUUID = "365a6beb-a072-4b92-96c4-cc39fff11918";
            };
        }
      );

      nixosConfigurations.picache = nixosSystem {
        specialArgs = { inherit inputs secrets; };

        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };

        modules = [
          lix-module.nixosModules.lixFromNixpkgs
          raspberry-pi-nix.nixosModules.raspberry-pi
          self.nixosModules.default
          ./configuration.nix
        ];
      };

      apps = forEachSystem (
        { pkgs, ... }:
        rec {
          default = deploy;
          deploy = import ./apps/deploy.nix { inherit pkgs; };
          write-to-disk = import ./apps/write-to-disk.nix { inherit inputs pkgs self; };
        }
      );
    };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://quinneden.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "quinneden.cachix.org-1:1iSAVU2R8SYzxTv3Qq8j6ssSPf0Hz+26gfgXkvlcbuA="
    ];
  };
}
