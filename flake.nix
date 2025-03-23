{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "git+ssh://git@github.com/quinneden/secrets.git?ref=main&shallow=1";
      inputs = { };
    };
  };
  outputs =
    {
      lix-module,
      nixpkgs,
      self,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      forEachSystem =
        function:
        lib.genAttrs
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
    in
    {
      packages = forEachSystem (
        { pkgs }:
        {
          image =
            let
              inherit (self.nixosConfigurations.picache) config;
            in
            config.system.build.btrfsImage;

          writeToDisk = pkgs.callPackage ./scripts/write-to-disk.nix { inherit lib; };
        }
      );

      nixosConfigurations.picache = lib.nixosSystem {
        specialArgs = { inherit inputs lib; };

        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };

        modules = [
          lix-module.nixosModules.lixFromNixpkgs
          # raspberry-pi-nix.nixosModules.raspberry-pi
          inputs.nixos-hardware.nixosModules.raspberry-pi-4
          inputs.sops-nix.nixosModules.sops
          ./configuration.nix
        ];
      };

      apps = forEachSystem (
        { pkgs, ... }:
        rec {
          default = deploy;
          deploy = import ./apps/deploy.nix { inherit pkgs; };
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
