#!/bin/sh
set -eu

namespace=JetBrains
extension=intellij-server
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
prefix=${INTELLIJ_LSP_HOME:-"$data_home/jetbrains-intellij-lsp"}
bin_dir=${INTELLIJ_LSP_BIN_DIR:-"$HOME/.local/bin"}
accept_eula=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--accept-eula]

Downloads and verifies the current JetBrains IntelliJ language server, asks
you to accept its EAP agreement, and installs the intellij-lsp launcher.

Environment:
  INTELLIJ_LSP_HOME      Installation directory
  INTELLIJ_LSP_BIN_DIR   Launcher directory (default: ~/.local/bin)
EOF
}

case ${1:-} in
  '') ;;
  --accept-eula) accept_eula=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

for command in curl python3 unzip tar; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  }
done

case "$(uname -s):$(uname -m)" in
  Linux:x86_64|Linux:amd64) target=linux-x64 ;;
  Linux:aarch64|Linux:arm64) target=linux-arm64 ;;
  Darwin:x86_64|Darwin:amd64) target=darwin-x64 ;;
  Darwin:arm64|Darwin:aarch64) target=darwin-arm64 ;;
  *) printf 'Unsupported platform: %s %s\n' "$(uname -s)" "$(uname -m)" >&2; exit 1 ;;
esac

tmp=$(mktemp -d "${TMPDIR:-/tmp}/intellij-lsp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

api="https://open-vsx.org/api/$namespace/$extension/$target/latest"
printf 'Reading current release metadata from Open VSX…\n'
curl -fsSL --retry 3 "$api" -o "$tmp/release.json"
vsix_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["files"]["download"])' "$tmp/release.json")
extension_version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$tmp/release.json")

printf 'Downloading extension %s for %s…\n' "$extension_version" "$target"
curl -fL --retry 3 "$vsix_url" -o "$tmp/extension.vsix"
unzip -q "$tmp/extension.vsix" 'extension/server-bundle.json' 'extension/LICENSE.txt' -d "$tmp"

server_url=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["url"])' "$tmp/extension/server-bundle.json")
server_version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$tmp/extension/server-bundle.json")
expected_sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "$tmp/extension/server-bundle.json")
server_dir="$prefix/servers/$server_version"

if [ ! -x "$server_dir/bin/intellij-server" ]; then
  printf 'Downloading language server %s (about 390 MB)…\n' "$server_version"
  curl -fL --retry 3 "$server_url" -o "$tmp/server.tar.gz"
  if command -v sha256sum >/dev/null 2>&1; then
    actual_sha=$(sha256sum "$tmp/server.tar.gz" | awk '{print $1}')
  else
    actual_sha=$(shasum -a 256 "$tmp/server.tar.gz" | awk '{print $1}')
  fi
  if [ "$actual_sha" != "$expected_sha" ]; then
    printf 'Checksum mismatch: expected %s, got %s\n' "$expected_sha" "$actual_sha" >&2
    exit 1
  fi
  extract_dir="$server_dir.tmp.$$"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir" "$(dirname "$server_dir")"
  tar -xzf "$tmp/server.tar.gz" --strip-components=1 -C "$extract_dir"
  rm -rf "$server_dir"
  mv "$extract_dir" "$server_dir"
fi

if command -v sha256sum >/dev/null 2>&1; then
  eula_hash=$(sha256sum "$server_dir/EULA.txt" | cut -c1-16)
else
  eula_hash=$(shasum -a 256 "$server_dir/EULA.txt" | cut -c1-16)
fi

if [ "$accept_eula" != true ]; then
  cat "$server_dir/EULA.txt"
  printf '\nType "accept" to accept this agreement and continue: '
  read -r answer
  [ "$answer" = accept ] || { printf 'Agreement not accepted; installation stopped.\n' >&2; exit 1; }
fi

mkdir -p "$prefix" "$bin_dir"
ln -sfn "servers/$server_version" "$prefix/current"
printf '%s\n' "$eula_hash" > "$prefix/accepted-eula-hash"
cp "$(dirname "$0")/bin/intellij-lsp" "$bin_dir/intellij-lsp"
chmod 755 "$bin_dir/intellij-lsp" "$server_dir/bin/intellij-server"

printf '\nInstalled IntelliJ language server %s.\n' "$server_version"
printf 'Launcher: %s\n' "$bin_dir/intellij-lsp"
case :$PATH: in
  *:"$bin_dir":*) ;;
  *) printf 'Add %s to PATH before starting Helix.\n' "$bin_dir" ;;
esac
