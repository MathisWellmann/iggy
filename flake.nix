{
  description = "Apache Iggy message streaming platform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flakeUtils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flakeUtils,
    rust-overlay,
    ...
  }:
    (flakeUtils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        nativeBuildInputs = with pkgs; [
          pkg-config
        ];
        # Pre-fetch the V8 binary.
        rustyV8Lib = pkgs.fetchurl {
          url = "https://github.com/denoland/rusty_v8/releases/download/v137.3.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
          sha256 = "sha256-omgf3lMBir0zZgGPEyYX3VmAAt948VbHvG0v9gi1ZWc=";
        };

        buildInputs = with pkgs; [
          rust
          openssl
          libffi
          hwloc
          cacert
        ];
        rust_tools = with pkgs; [
          taplo # Format `toml` files like `Cargo.toml`
          cargo-nextest
        ];
        nix_tools = with pkgs; [
          alejandra # Nix code formatter
          deadnix # Dead code detection for nix
          statix # Highlights nix antipatterns
        ];

        # Build the embedded Web UI (SvelteKit static adapter).
        webUI = pkgs.buildNpmPackage {
          pname = "iggy-web-ui";
          version = "0.2.1-edge.1";
          src = ./web;
          npmDepsHash = "sha256-5j4+rVnt8E4Pra2gjefi4cML6JQrYhkiSRGCxqPLyEc=";
          buildPhase = ''
            npm run build:static
          '';
          installPhase = ''
            cp -r build/static $out
          '';
        };

        mkPackage = pname:
          pkgs.rustPlatform.buildRustPackage {
            name = pname;
            src = ./.;

            cargoBuildFlags = ["--bin" "${pname}"];
            cargoLock.lockFile = ./Cargo.lock;
            doCheck = false; # Nix sandboxing won't permit setting ulimits, so chek would fail.
            env.RUSTY_V8_ARCHIVE = "${rustyV8Lib}";
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

            inherit buildInputs nativeBuildInputs;
          };
      in {
        # Packages can be built with `nix build .#iggy-server` for example.
        packages = {
          iggy-server = (mkPackage "iggy-server").overrideAttrs (old: {
            preBuild = ''
              # Place pre-built Web UI assets where rust-embed expects them.
              mkdir -p web/build
              cp -rL --no-preserve=mode ${webUI} web/build/static
            '';
          });
          iggy-cli = mkPackage "iggy-cli";
          iggy-bench = mkPackage "iggy-bench";
        };

        # Reproducible development shell can be entered with `nix develop`
        devShells = {
          default = pkgs.mkShell {
            name = "iggy-dev";
            buildInputs = buildInputs ++ nix_tools ++ rust_tools;
            inherit nativeBuildInputs;
          };
        };
      }
    ))
    // {
      nixosModules.default = import ./nix/module.nix self;
    };
}
