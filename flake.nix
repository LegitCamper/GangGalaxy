# {
#   description = "A 'snake game'";
#   inputs = {
#     nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
#     flake-utils.url = "github:numtide/flake-utils";
#     rust-overlay.url = "github:oxalica/rust-overlay";
#   };
#   outputs = { self, nixpkgs, rust-overlay, flake-utils }:
#     with flake-utils.lib;
#     eachSystem [ system.x86_64-linux ] (system:
#       let
#         overlays = [
#           (import rust-overlay)
#           (self: super: {
#             rustToolchain = let rust = super.rust-bin;
#             in if builtins.pathExists ./rust-toolchain.toml then
#               rust.fromRustupToolchainFile ./rust-toolchain.toml
#             else if builtins.pathExists ./rust-toolchain then
#               rust.fromRustupToolchainFile ./rust-toolchain
#             else
#               rust.stable.latest.default;
#           })
#         ];
#         pkgs = (import nixpkgs) { inherit system overlays; };
#       in rec {
#         packages.default = packages."${system}";

#         devShells.default = pkgs.mkShell {
#           packages = with pkgs; [
#             python3
#             inkscape
#             blender
#             imagemagick
#             pkgconfig
#             clang
#             rustToolchain
#             openssl
#             pkg-config
#             cargo-deny
#             cargo-edit
#             cargo-watch
#             rustup
#             rust-analyzer
#             # Vulkan
#             vulkan-tools
#             vulkan-headers
#             vulkan-loader
#             vulkan-validation-layers
#             alsaLib # Sound support
#             libudev-zero # device management
#             lld # fast linker
#             xlibsWrapper
#             xorg.libXcursor
#             xorg.libXrandr
#             xorg.libXi
#             x11
#             libxkbcommon
#             wayland
#           ];
#           shellHook = ''
#             export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${
#               pkgs.lib.makeLibraryPath [ udev alsaLib vulkan-loader ]
#             }"'';
#           # RUST_SRC_PATH = rustPlatform.rustLibSrc;
#         };
#       });

# }

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    nur.url = "github:polygon/nur.nix";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = { self, rust-overlay, nixpkgs, nur, naersk }:
    let
      systems = [ "aarch64-linux" "i686-linux" "x86_64-linux" ];
      overlays = [ (import rust-overlay) ];
      program_name = "bevy_nix_vscode_template";
    in builtins.foldl' (outputs: system:

      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit overlays system; };

        rust-bin = pkgs.rust-bin.selectLatestNightlyWith (toolchain:
          toolchain.default.override {
            targets = [ "wasm32-unknown-unknown" ];
            extensions = [ "rust-src" ];
          });
        naersk-lib = naersk.lib.${system}.override {
          cargo = rust-bin;
          rustc = rust-bin;
        };

        rust-dev-deps = with pkgs; [
          cargo-deny
          cargo-edit
          cargo-watch
          rustup
          rust-analyzer
          rustfmt
          lldb
          cargo-geiger
          nur.packages.${system}.wasm-server-runner
          renderdoc
        ];
        build-deps = with pkgs; [ pkgconfig mold clang makeWrapper lld ];
        runtime-deps = with pkgs; [
          alsa-lib
          udev
          xorg.libX11
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXi
          xorg.libxcb
          libGL
          vulkan-loader
          vulkan-headers
        ];
      in {
        devShell.${system} = let
          all_deps = runtime-deps ++ build-deps ++ rust-dev-deps
            ++ [ rust-bin ];
        in pkgs.mkShell {
          buildInputs = all_deps;
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (all_deps);
          PROGRAM_NAME = program_name;
          shellHook = ''
            export CARGO_MANIFEST_DIR=$(pwd)
          '';
        };
        packages.${system} = {
          app = naersk-lib.buildPackage {
            pname = program_name;
            root = ./.;
            buildInputs = runtime-deps;
            nativeBuildInputs = build-deps;
            overrideMain = attrs: {
              fixupPhase = ''
                wrapProgram $out/bin/${program_name} \
                  --prefix LD_LIBRARY_PATH : ${
                    pkgs.lib.makeLibraryPath runtime-deps
                  } \
                  --set CARGO_MANIFEST_DIR $out/share/bevy_nix_vscode_template
                mkdir -p $out/share/${program_name}
                cp -a assets $out/share/${program_name}'';
              patchPhase = ''
                sed -i s/\"dynamic\"// Cargo.toml
              '';
            };
          };
          wasm = self.packages.${system}.app.overrideAttrs (final: prev: {
            CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
            fixupPhase = "";
          });
        };
        defaultPackage.${system} = self.packages.${system}.app;
        apps.${system}.wasm = {
          type = "app";
          program = "${pkgs.writeShellScript "wasm-run" "${
              nur.packages.${system}.wasm-server-runner
            }/bin/wasm-server-runner ${
              self.packages.${system}.wasm
            }/bin/${program_name}.wasm"}";
        };
      }) { } systems;

}
