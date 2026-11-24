#!/usr/bin/env bash
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Hans Rosenfeld
#

set -euo pipefail

OPENWRT_VERSION="${1:-25.12.6}"
API_URL="https://sysupgrade.openwrt.org"
OUT_NAME="openwrt-oi-wifi-${OPENWRT_VERSION}-x86-64-efi.img.gz"

echo "==> Issuing build request for OpenWrt ${OPENWRT_VERSION} (x86/64 generic)..."

PAYLOAD=$(python3 - "$OPENWRT_VERSION" << 'PY'
import json, sys

version = sys.argv[1]
with open("packages.txt") as f:
    pkgs = [line.strip() for line in f if line.strip() and not line.startswith("#")]

with open("uci-defaults.sh") as f:
    defaults = f.read()

print(json.dumps({
    "distro": "openwrt",
    "version": version,
    "target": "x86/64",
    "profile": "generic",
    "diff_packages": True,
    "packages": pkgs,
    "defaults": defaults
}))
PY
)

HTTP_OUT=$(curl -sS -w "\n%{http_code}" -X POST "${API_URL}/api/v1/build" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")

HTTP_CODE=$(printf '%s\n' "$HTTP_OUT" | tail -n 1)
RESP=$(printf '%s\n' "$HTTP_OUT" | sed '$d')

if [ -z "$RESP" ] || [ "$HTTP_CODE" -ge 400 ]; then
    echo "API error (HTTP ${HTTP_CODE}): ${RESP}" >&2
    exit 1
fi

REQ_HASH=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("request_hash",""))' "$RESP")
if [ -z "$REQ_HASH" ]; then
    echo "Error starting build: $RESP" >&2
    exit 1
fi

echo "==> Build process started (request_hash=${REQ_HASH}), waiting for completion ..."

while true; do
    STATUS_JSON=$(curl -sS "${API_URL}/api/v1/build/${REQ_HASH}")

    read -r STATUS DETAIL HAS_IMAGES < <(python3 - "$STATUS_JSON" << 'PY'
import json, sys
d = json.loads(sys.argv[1])
print(d.get("status", ""), "|", d.get("detail", ""), "|", "1" if "images" in d else "0")
PY
)

    STATUS=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("status",""))' "$STATUS_JSON")
    DETAIL=$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("detail",""))' "$STATUS_JSON")

    if echo "$STATUS_JSON" | grep -q '"images"'; then
        break
    elif [[ "$STATUS" =~ ^[45][0-9][0-9]$ ]] || [ "$STATUS" = "failed" ]; then
        echo "Build failed: $STATUS_JSON" >&2
        exit 1
    fi
    echo "    Status: ${STATUS:-building} (${DETAIL})"
    sleep 5
done

IMG_URL=$(python3 - "$API_URL" "$STATUS_JSON" << 'PY'
import json, sys
api = sys.argv[1]
d = json.loads(sys.argv[2])
bin_dir = d["bin_dir"]
for img in d["images"]:
    if img.get("type") == "combined-efi" and img.get("filesystem") == "squashfs":
        print(f"{api}/store/{bin_dir}/{img['name']}")
        sys.exit(0)
sys.exit(1)
PY
)

echo "==> Downloading built EFI-Image: ${IMG_URL}"
curl -fL "${IMG_URL}" -o "${OUT_NAME}"
sha256sum "${OUT_NAME}" | tee "${OUT_NAME}.sha256"
echo "==> Completed: ${OUT_NAME}"
