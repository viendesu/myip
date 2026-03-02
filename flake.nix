{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nixos-module.nix ];
        config.services.myip.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };

      overlays.default = final: prev:
        let
          pkgs = prev.extend rust-overlay.overlays.default;
          rustToolchain = pkgs.rust-bin.stable.latest.minimal;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };
        in
        {
          myip = rustPlatform.buildRustPackage {
            pname = "myip";
            version = "1.0.0";
            src = self;
            cargoLock.lockFile = ./Cargo.lock;
          };
        };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        rustToolchain = pkgs.rust-bin.stable.latest.minimal;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };
        myip = rustPlatform.buildRustPackage {
          pname = "myip";
          version = "1.0.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
        };

      in
      {
        packages.default = myip;
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.rust-bin.stable.latest.default ];
        };
      }
    );
}
