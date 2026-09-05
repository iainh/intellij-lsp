# IntelliJ language server for Helix

This project runs the language server from JetBrains' **Java and Kotlin by IntelliJ IDEA** VS Code extension as a standalone stdio LSP server for [Helix](https://helix-editor.com/). It downloads JetBrains' original binary, verifies its published SHA-256 checksum and adds only a small launcher.

This is an unofficial integration. JetBrains supports VS Code and VS Code forks during the preview; Helix is not an officially supported client.

## Important preview terms

The server is proprietary preview software governed by the bundled **JetBrains LSP Extension Public EAP Agreement**. The installer displays that agreement and requires your acceptance. In particular:

- use is limited to internal evaluation and feedback during the EAP term;
- each preview build expires 30 days after its release;
- you may not redistribute the server;
- the future 1.0 release will require an IntelliJ IDEA Ultimate subscription.

The installer therefore downloads the server directly from JetBrains rather than including it here. Re-run the installer when a build expires.

## Requirements

- Linux or macOS on x86-64 or ARM64
- Helix 25.07 or newer
- `curl`, `python3`, `tar` and `unzip`
- a JDK suitable for your project
- Maven, Gradle or Bazel when your project uses it
- about 1.6 GB of disk space

## Install with Nix

The flake supports Linux and macOS on x86-64 and ARM64. It pins JetBrains' server archive and checksum so builds are reproducible. You need Nix 2.18 or newer with flakes enabled.

1. Build the package, review the EULA and record your acceptance:

   ```sh
   nix build
   nix run . -- --show-eula
   nix run . -- --accept-eula
   ```

   The final command displays the EULA again. Type `accept` to continue. Acceptance is stored outside the Nix store under `${XDG_DATA_HOME:-~/.local/share}/jetbrains-intellij-lsp`.

2. Install the launcher in your profile:

   ```sh
   nix profile install .#intellij-lsp
   ```

   Alternatively, enter the included development shell. It provides `intellij-lsp`, Helix, JDK 21 and Maven:

   ```sh
   nix develop
   ```

3. Continue with the Helix configuration in steps 3–5 under [Install without Nix](#install-without-nix).

## Install without Nix

1. Clone or download this directory, then run:

   ```sh
   ./install.sh
   ```

   Read the agreement and type `accept` when prompted. For an unattended installation, read the bundled agreement from the [Open VSX package](https://open-vsx.org/extension/JetBrains/intellij-server) first, then record your acceptance with:

   ```sh
   ./install.sh --accept-eula
   ```

   The default locations are `~/.local/share/jetbrains-intellij-lsp` for the server and `~/.local/bin/intellij-lsp` for the launcher. Override them with `INTELLIJ_LSP_HOME` and `INTELLIJ_LSP_BIN_DIR`.

2. Ensure `~/.local/bin` is on `PATH`:

   ```sh
   export PATH="$HOME/.local/bin:$PATH"
   intellij-lsp --version
   ```

3. Copy the Helix configuration into your user configuration:

   ```sh
   mkdir -p ~/.config/helix
   test -e ~/.config/helix/languages.toml || cp helix/languages.toml ~/.config/helix/languages.toml
   ```

   If the destination already exists, the command leaves it unchanged. Merge the three blocks from [`helix/languages.toml`](helix/languages.toml) into your file instead. Replace any existing `language-servers` entry for Java or Kotlin if you want IntelliJ to be the only server.

4. Check that Helix finds the launcher:

   ```sh
   hx --health java
   hx --health kotlin
   ```

   Each report should list `intellij-idea` with a green check mark under configured language servers.

5. Start Helix from the root of a Maven, Gradle or Bazel project:

   ```sh
   hx src/main/java/com/example/App.java
   ```

   Initial project import and indexing can take a few minutes. Confirm code intelligence after it settles:

   - put the cursor on a method call and press `gd`; Helix should jump to its declaration;
   - introduce a type error and press `]d`; Helix should jump to the diagnostic and show IntelliJ's message.

   Run `:log-open` in Helix if the server does not start. The log should contain `intellij-idea` without an LSP exit error. The launcher writes the detailed server log path near the top of that file.

## Privacy and settings

The launcher passes `--data-sharing none`, so it does not send usage statistics or error reports. It defaults the product-terms region to `americas`. You can change either value for a Helix session:

```sh
INTELLIJ_LSP_REGION=europe INTELLIJ_LSP_DATA_SHARING=anonymous hx .
```

Valid regions are `africa`, `americas`, `apac`, `china`, `europe`, `middle_east` and `oceania`. Valid data-sharing values are `none`, `anonymous` and `full`.

Add JVM options through `IJ_JAVA_OPTIONS`, for example:

```sh
IJ_JAVA_OPTIONS="-Xmx4g" hx .
```

Indexes are stored under `${XDG_CACHE_HOME:-~/.cache}/jetbrains-intellij-lsp/workspaces/`, separately for each project working directory.

## Update or remove

Run `./install.sh` again to install the current preview build and renew EULA acceptance if its text changed.

The flake is deliberately pinned. Update `version`, all four archive URLs and their hashes in `flake.nix` when JetBrains publishes a new preview, then rebuild it. Updating only `flake.lock` updates Nixpkgs, not the language server.

Remove a Nix profile installation with:

```sh
nix profile remove intellij-lsp
```

To remove the manual installation and all shared acceptance and cache data:

```sh
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/jetbrains-intellij-lsp"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/jetbrains-intellij-lsp"
rm -f "$HOME/.local/bin/intellij-lsp"
```

Then remove the `intellij-idea` blocks from `~/.config/helix/languages.toml`.

## Known limitations

- JetBrains does not currently document or support Helix as a client.
- Helix supports standard LSP features, but VS Code-only UI, IntelliJ custom commands and DAP debugging are not wired up by this configuration.
- The preview can change or expire without notice. Run the installer again to update.
- Use JetBrains' free, Apache-2.0-licensed [Kotlin LSP](https://github.com/Kotlin/kotlin-lsp) instead for pure Kotlin projects when you do not need IntelliJ's mixed Java/Kotlin project support.

## Sources

- [JetBrains announcement](https://blog.jetbrains.com/idea/2026/08/intellij-idea-goes-lsp/)
- [JetBrains extension documentation](https://www.jetbrains.com/help/intellij-vscode/About-instance.html)
- [Open VSX package](https://open-vsx.org/extension/JetBrains/intellij-server)
