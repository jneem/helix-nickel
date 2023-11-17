{
  description = "Devshell providing nickel and nls";
  
  inputs = {
    nixpkgs.url = "nixpkgs";
    nickel.url = "github:tweag/nickel";
    jsncl.url = "github:nickel-lang/json-schema-to-nickel";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };
  
  outputs = { self, nixpkgs, flake-utils, nickel, jsncl, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          localSystem = { inherit system; };
          overlays = [ (import rust-overlay) ];
        };
        nickel-pkgs = nickel.packages."${system}";

        ra-fixer = pkgs.rustPlatform.buildRustPackage {
          pname = "helix-nickel";
          version = "0.1.0";
          src = pkgs.lib.sources.sourceByRegex ./. [ "Cargo\..*$" "src$" "src/main.rs"];
          cargoLock = { lockFile = ./Cargo.lock; };
        };

        jschema-to-ncl = jsncl.packages.${system}.default;

        generate-rust-analyzer-nickel = pkgs.writeShellScriptBin "generate-rust-analyzer-nickel" ''
          ${pkgs.rust-analyzer}/bin/rust-analyzer --print-config-schema | ${ra-fixer}/bin/helix-nickel | ${jschema-to-ncl}/bin/json-schema-to-nickel
        '';

        rust-analyzer-config-ncl = pkgs.runCommand "ra-ncl" {} ''
          mkdir $out
          ${pkgs.rust-analyzer}/bin/rust-analyzer --print-config-schema | ${ra-fixer}/bin/helix-nickel | ${jschema-to-ncl}/bin/json-schema-to-nickel > $out/ra-config.ncl
        '';

        helix-ncl = pkgs.runCommand "hx-ncl" {} ''
          mkdir $out
          ${jschema-to-ncl}/bin/json-schema-to-nickel ${./helix-config.json} > $out/hx-config.ncl
          ${jschema-to-ncl}/bin/json-schema-to-nickel ${./helix-language.json} > $out/hx-language.ncl
        '';

      in {
        packages.ra-fixer = ra-fixer;
        packages.rust-analyzer-config-ncl = rust-analyzer-config-ncl;
        packages.helix-ncl = helix-ncl;
        packages.default = helix-ncl;
        devShell = pkgs.mkShell {
          nativeBuildInputs = [
            generate-rust-analyzer-nickel
            nickel-pkgs.default
            nickel-pkgs.lsp-nls
            pkgs.rust-analyzer
            pkgs.rust-bin.stable.latest.default
            jschema-to-ncl
          ];
        };
      }
    );
}
