#!/usr/bin/env bash
set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────

APP="cli"           # ← must match the APP name in build.ts
BINDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/bin" && pwd)"

# ─── Detect OS ─────────────────────────────────────────────────────────────

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux)  PLATFORM="linux"  ;;
  Darwin) PLATFORM="macos"  ;;
  *)
    echo "❌  Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

# ─── Detect Arch ───────────────────────────────────────────────────────────

case "$ARCH" in
  x86_64)          ARCH_SUFFIX="x64"   ;;
  arm64 | aarch64) ARCH_SUFFIX="arm64" ;;
  *)
    echo "❌  Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# ─── Resolve binary ────────────────────────────────────────────────────────

BINARY="${BINDIR}/${APP}-${PLATFORM}-${ARCH_SUFFIX}"

if [[ ! -f "$BINARY" ]]; then
  echo "❌  Binary not found: $BINARY" >&2
  echo "   Run 'bun run build.ts' first to compile the project." >&2
  exit 1
fi

if [[ ! -x "$BINARY" ]]; then
  chmod +x "$BINARY"
fi

# ─── Execute ───────────────────────────────────────────────────────────────

exec "$BINARY" "$@"