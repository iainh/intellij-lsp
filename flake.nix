{
  description = "JetBrains IntelliJ language server launcher for Helix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      version = "263.3533.0";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      archives = {
        x86_64-linux = {
          url = "https://download.jetbrains.com/language-server/intellij-server/${version}/intellij-server-${version}.tar.gz";
          hash = "sha256-yqTRISNs5ciQRpWoe+N1po+tqbnKQjFFB3P5/Z14w8M=";
          format = "tar.gz";
        };
        aarch64-linux = {
          url = "https://download.jetbrains.com/language-server/intellij-server/${version}/intellij-server-${version}-aarch64.tar.gz";
          hash = "sha256-OJR9Kf2OdYn4+9V5Sy5YDUCDfN6OYMoOILLLIQ6oB24=";
          format = "tar.gz";
        };
        x86_64-darwin = {
          url = "https://download.jetbrains.com/language-server/intellij-server/${version}/intellij-server-${version}.sit";
          hash = "sha256-6ecMZ6bac1HUzZ5zyZKoFCWyYcvFVAH2igqPDXUOYmg=";
          format = "sit";
        };
        aarch64-darwin = {
          url = "https://download.jetbrains.com/language-server/intellij-server/${version}/intellij-server-${version}-aarch64.sit";
          hash = "sha256-BM7NT9BLxCypV+AGNn1aQsot5rcuX1FJRwzFxwEUbaQ=";
          format = "sit";
        };
      };
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = package:
              builtins.elem (nixpkgs.lib.getName package) [ "intellij-lsp" ];
          };
          lib = pkgs.lib;
          archive = archives.${system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "intellij-lsp";
          inherit version;

          src = pkgs.fetchurl {
            inherit (archive) url hash;
          };
          dontUnpack = true;

          nativeBuildInputs = [ pkgs.makeWrapper ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.unzip ];
          buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.alsa-lib
            pkgs.fontconfig
            pkgs.freetype
            pkgs.glib
            pkgs.libx11
            pkgs.libxext
            pkgs.libxi
            pkgs.libxrender
            pkgs.libxtst
            pkgs.libxkbcommon
            pkgs.stdenv.cc.cc.lib
            pkgs.wayland
            pkgs.zlib
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/libexec/intellij-server" "$out/libexec/launcher" "$out/bin"
          '' + (if archive.format == "tar.gz" then ''
            tar -xzf "$src" --strip-components=1 -C "$out/libexec/intellij-server"
          '' else ''
            mkdir extracted
            unzip -q "$src" -d extracted
            entries=(extracted/*)
            if [[ ''${#entries[@]} -eq 1 && -d ''${entries[0]} ]]; then
              cp -R "''${entries[0]}/." "$out/libexec/intellij-server/"
            else
              cp -R extracted/. "$out/libexec/intellij-server/"
            fi
          '') + ''
            cp ${./bin/intellij-lsp} "$out/libexec/launcher/intellij-lsp"
            patchShebangs "$out/libexec/launcher/intellij-lsp"
            chmod +x "$out/libexec/intellij-server/bin/intellij-server"
            makeWrapper "$out/libexec/launcher/intellij-lsp" "$out/bin/intellij-lsp" \
              --set INTELLIJ_LSP_SERVER_DIR "$out/libexec/intellij-server" \
              --prefix PATH : ${lib.makeBinPath [ pkgs.coreutils pkgs.gawk ]}
            runHook postInstall
          '';

          meta = {
            description = "IntelliJ IDEA Java and Kotlin language server with a standalone launcher";
            homepage = "https://blog.jetbrains.com/idea/2026/08/intellij-idea-goes-lsp/";
            license = lib.licenses.unfree;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = systems;
            mainProgram = "intellij-lsp";
          };
        };
    in
    {
      packages = forAllSystems (system: {
        default = packageFor system;
        intellij-lsp = packageFor system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/intellij-lsp";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.default
              pkgs.helix
              pkgs.jdk21
              pkgs.maven
            ];
          };
        });
    };
}
