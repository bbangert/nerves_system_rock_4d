#!/bin/sh
#
# U-Boot finds its env by GPT p1's unique GUID. If the fragment and fwup
# disagree, U-Boot boots on its default env forever: no A/B, no revert.
#
# Usage: scripts/check-env-uuid.sh [repo dir]

set -e

DIR=${1:-$(cd "$(dirname "$0")/.." && pwd)}
FRAGMENT=$DIR/uboot/ufs.fragment
FWUP_COMMON=$DIR/fwup_include/fwup-common.conf

uboot_uuid=$(sed -n 's/^CONFIG_ENV_SCSI_PART_UUID="\([^"]*\)".*/\1/p' "$FRAGMENT")
fwup_uuid=$(sed -n 's/^define(UBOOT_ENV_PART_GUID, *"\([^"]*\)").*/\1/p' "$FWUP_COMMON")

if [ -z "$uboot_uuid" ] || [ -z "$fwup_uuid" ]; then
    echo "check-env-uuid: could not read CONFIG_ENV_SCSI_PART_UUID ($FRAGMENT) or UBOOT_ENV_PART_GUID ($FWUP_COMMON)" >&2
    exit 1
fi

# GPT GUIDs compare case-insensitively.
uboot_uuid=$(echo "$uboot_uuid" | tr 'A-F' 'a-f')
fwup_uuid=$(echo "$fwup_uuid" | tr 'A-F' 'a-f')

if [ "$uboot_uuid" != "$fwup_uuid" ]; then
    echo "check-env-uuid: CONFIG_ENV_SCSI_PART_UUID=$uboot_uuid but UBOOT_ENV_PART_GUID=$fwup_uuid" >&2
    exit 1
fi
