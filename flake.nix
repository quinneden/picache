{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    # nixos-generators = {
    #   url = "github:nix-community/nixos-generators";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-2.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      # nixos-generators,
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
          inputs.raspberry-pi-nix.nixosModules.raspberry-pi
          inputs.raspberry-pi-nix.nixosModules.sd-image
          ./configuration.nix
          ./modules
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
                --target-host "qeden@picache" \
                --use-remote-sudo \
                --option require-sigs false \
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

      #       devShells = forEachSystem (
      #         system:
      #         let
      #           pkgs = nixpkgs.legacyPackages.${system};
      #           lib = nixpkgs.lib;
      #         in
      #         {
      #           default = pkgs.mkShellNoCC {
      #             shellHook = ''
      #                     set -e
      #
      #               ${lib.getExe pkgs.nixos-rebuild} switch \
      #                 --fast --show-trace \
      #                 --flake .#picache \
      #                 --target-host "root@picache"
      #
      #               ret="$?"
      #
      #               [[ $ret -eq 0 ]] && exit 0
      #             '';
      #           };
      #         }
      #       );
    };

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
