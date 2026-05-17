#!/bin/bash
set -euo pipefail

source ./nc_talk_settings.inc

# Create local state files once at loop startup, if they do not already exist
mkdir -p "$(dirname "$NC_TALK_HISTORY_FILE")"
mkdir -p "$(dirname "$NC_TALK_LAST_ID_FILE")"

touch "$NC_TALK_HISTORY_FILE"

if [ ! -f "$NC_TALK_LAST_ID_FILE" ]; then
  echo "0" > "$NC_TALK_LAST_ID_FILE"
fi

LAST_ID_FILE="$NC_TALK_LAST_ID_FILE"

while true; do
  LAST_ID="$(cat "$LAST_ID_FILE")"

  RESPONSE="$(
    curl -sS -u "$NC_USER:$NC_APP_PASSWORD" \
      -H "OCS-APIRequest: true" \
      -H "Accept: application/json" \
      "$NC_URL/ocs/v2.php/apps/spreed/api/v1/chat/$TALK_TOKEN?limit=20&lookIntoFuture=0"
  )"

  NEWEST_ID="$(
    echo "$RESPONSE" | jq -r '.ocs.data | map(.id) | max // 0'
  )"

  MSG_JSON="$(
    echo "$RESPONSE" | jq -c --argjson last "$LAST_ID" --arg bot "$NC_USER" '
      [
        .ocs.data
        | sort_by(.id)
        | .[]
        | select(.id > $last)
        | select(.messageType == "comment")
        | select(.actorId != $bot)
      ]
      | first // empty
    '
  )"

  if [ -n "$MSG_JSON" ]; then
    MESSAGE="$(echo "$MSG_JSON" | jq -r '.message')"
    ACTOR_ID="$(echo "$MSG_JSON" | jq -r '.actorId')"
    ACTOR_NAME="$(echo "$MSG_JSON" | jq -r '.actorDisplayName // .actorId')"
  else
    MESSAGE=""
    ACTOR_ID=""
    ACTOR_NAME=""
  fi

  if [ -n "$MESSAGE" ] && [ "$MESSAGE" != "null" ]; then
    if [ "${DEBUG_ECHO:-0}" = "1" ]; then
      echo "Received: $MESSAGE"
    fi
    
    
    if [ "${DEBUG_ECHO:-0}" = "1" ]; then
      $NC_TALK_DIR/nc_talk_send.sh "Debug received: $MESSAGE"
    else

    ANSWER="$(NC_TALK_BOT_NAME="$NC_USER" $NC_TALK_DIR/nc_hermes_ask.sh "$ACTOR_NAME: $MESSAGE")"
    
    TS="$(date '+%Y-%m-%d %H:%M:%S')"

    {
      echo "[$TS] $ACTOR_NAME: $MESSAGE"
      echo "[$TS] $NC_USER: $ANSWER"   
    } >> "$NC_TALK_HISTORY_FILE"

    $NC_TALK_DIR/nc_talk_send.sh "$ANSWER"
  fi


  fi

  if [ "$NEWEST_ID" -gt "$LAST_ID" ]; then
    echo "$NEWEST_ID" > "$LAST_ID_FILE"
  fi

  sleep 3
done
