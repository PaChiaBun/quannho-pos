#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# scripts/qn_cli.sh — CLI Wrapper for Quán Nhỏ POS Commands
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/qn" "$@"
