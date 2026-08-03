#!/usr/bin/env bash
# Refresh the bundled hardware-models.json from DeviceNameKit raw JSON
# (no HTML scraping). Safe to run manually or from CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/SYM/Models/hardware-models.json"
BASE_URL="https://raw.githubusercontent.com/kimdaehee0824/DeviceNameKit/main/DeviceName"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for platform in iOS watchOS tvOS visionOS; do
  curl -fsSL "$BASE_URL/${platform}.json" -o "$TMP/${platform}.json"
done

python3 - "$TMP" "$OUT" <<'PY'
import json, sys
from pathlib import Path

tmp, out = Path(sys.argv[1]), Path(sys.argv[2])
merged = {}
for name in ("iOS.json", "watchOS.json", "tvOS.json", "visionOS.json"):
    merged.update(json.loads((tmp / name).read_text(encoding="utf-8")))
merged.setdefault("i386", "Simulator")
merged.setdefault("x86_64", "Simulator")
merged.setdefault("arm64", "Simulator")
ordered = {k: merged[k] for k in sorted(merged)}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(ordered, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {len(ordered)} models → {out}")
PY
