{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
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
    in
    {
      packages = forEachSystem (system: {
        image =
          let
            config = self.nixosConfigurations.picache.config;
          in
          config.system.build.sdImage.overrideAttrs { compressImage = false; };
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
          lix-module.nixosModules.default
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
        ];
      };

      apps = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib writeShellApplication;

          deploySystem = writeShellApplication {
            name = "picache-deploy";
            runtimeInputs = [ pkgs.nixos-rebuild ];
            text = ''
              nixos-rebuild switch --fast --show-trace \
                --target-host "root@picache" \
                --flake .#picache
            '';
          };
        in
        rec {
          default = deploy;

          deploy = {
            type = "app";
            program = lib.getExe deploySystem;
          };
        }
      );
    };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
