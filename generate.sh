#!/usr/bin/env bash
set -euo pipefail

# Fastly CIDR Generator for AWG-Manager subscription
# Fetches Fastly public IP ranges and writes a plain-text CIDR list.
#
# Environment variables:
#   IPV4=1|0        Include IPv4 ranges (default: 1)
#   IPV6=1|0        Include IPv6 ranges (default: 1)
#   OUTPUT          Output file path (default: ./fastly.txt)
#   AUTO_COMMIT=1|0  Git commit & push if file changed (default: 0)

# --- Config -----------------------------------------------------------
: "${IPV4:=1}"
: "${IPV6:=1}"
: "${OUTPUT:=./fastly.txt}"
: "${AUTO_COMMIT:=0}"

FASTLY_API="https://api.fastly.com/public-ip-list"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Fetch ------------------------------------------------------------
echo "[*] Fetching Fastly IP list from ${FASTLY_API} ..."
JSON=$(curl -sSf "${FASTLY_API}") || {
    echo "[!] Failed to fetch Fastly API" >&2
    exit 1
}

# --- Filter -----------------------------------------------------------
JQ_FILTER=""
if [[ "$IPV4" == "1" ]]; then
    JQ_FILTER+=".addresses[]"
fi
if [[ "$IPV6" == "1" ]]; then
    if [[ -n "$JQ_FILTER" ]]; then
        JQ_FILTER+=", .ipv6_addresses[]"
    else
        JQ_FILTER+=".ipv6_addresses[]"
    fi
fi

if [[ -z "$JQ_FILTER" ]]; then
    echo "[!] Both IPV4 and IPV6 are disabled — nothing to generate" >&2
    exit 1
fi

CIDRS=$(echo "$JSON" | jq -r "${JQ_FILTER}" | sort -V)
V4_COUNT=$(echo "$JSON" | jq -r '.addresses | length')
V6_COUNT=$(echo "$JSON" | jq -r '.ipv6_addresses | length')

# --- Generate ---------------------------------------------------------
TMPFILE="${OUTPUT}.tmp.$$"

{
    echo "# Fastly CDN IP ranges"
    echo "# Generated: ${NOW}"
    echo "# Source:  ${FASTLY_API}"
    echo "#"
    if [[ "$IPV4" == "1" ]]; then
        echo "# IPv4 ranges: ${V4_COUNT}"
    fi
    if [[ "$IPV6" == "1" ]]; then
        echo "# IPv6 ranges: ${V6_COUNT}"
    fi
    echo ""
    echo "$CIDRS"
} > "$TMPFILE"

# --- Atomic replace ---------------------------------------------------
if [[ -f "$OUTPUT" ]] && diff -q "$TMPFILE" "$OUTPUT" > /dev/null 2>&1; then
    echo "[*] No changes detected, skipping update."
    rm -f "$TMPFILE"
else
    mv "$TMPFILE" "$OUTPUT"
    CIDR_COUNT=$(echo "$CIDRS" | wc -l)
    echo "[+] Written ${CIDR_COUNT} CIDR ranges to ${OUTPUT}"

    # --- Git auto-commit -----------------------------------------------
    if [[ "$AUTO_COMMIT" == "1" ]]; then
        if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            git add "$OUTPUT"
            # Only commit if there are staged changes
            if ! git diff --cached --quiet; then
                git commit -m "Update Fastly CIDR — ${NOW}"
                git push
                echo "[+] Committed and pushed to git"
            fi
        else
            echo "[!] AUTO_COMMIT=1 but not inside a git repo — skipping" >&2
        fi
    fi
fi
