#!/bin/bash
set -euo pipefail

source ./nc_talk_settings.inc

MESSAGE="${1:-}"

if [ -z "$MESSAGE" ]; then
  echo "Usage: $0 'message text'" >&2
  exit 1
fi

curl -sS -u "$NC_USER:$NC_APP_PASSWORD" \
  -H "OCS-APIRequest: true" \
  -H "Accept: application/json" \
  -X POST \
  --data-urlencode "message=$MESSAGE" \
  "$NC_URL/ocs/v2.php/apps/spreed/api/v1/chat/$TALK_TOKEN" >/dev/null
