{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-images.url = "github:nix-community/nixos-images";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      disko,
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
        genAttrs [
          "aarch64-darwin"
          "aarch64-linux"
        ] (system: function { pkgs = import nixpkgs { inherit system; }; });

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
      packages = forEachSystem (
        { pkgs }:
        {
          image =
            let
              image-config = nixosSystem {
                system = "aarch64-linux";

                specialArgs = { inherit inputs secrets; };

                modules = [
                  lix-module.nixosModules.default
                  raspberry-pi-nix.nixosModules.raspberry-pi
                  raspberry-pi-nix.nixosModules.sd-image
                  ./configuration.nix
                  ./modules/ssh.nix
                  ./modules/hardware.nix
                  ./modules/zsh.nix
                ];
              };

              config = image-config.config;
            in
            config.system.build.sdImage.overrideAttrs { compressImage = false; };
        }
      );

      nixosConfigurations.picache = nixosSystem {
        specialArgs = {
          inherit inputs secrets;
        };

        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };

        modules = [
          lix-module.nixosModules.lixFromNixpkgs
          raspberry-pi-nix.nixosModules.raspberry-pi
          disko.nixosModules.default
          ./configuration.nix
          ./modules
        ];
      };

      apps = forEachSystem (
        { pkgs, ... }:
        rec {
          default = deploy;
          deploy = import ./apps/deploy.nix { inherit pkgs; };
          install = import ./apps/install.nix { inherit inputs pkgs; };
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
