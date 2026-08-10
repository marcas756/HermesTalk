#!/bin/bash
set -euo pipefail

source ./nc_talk_settings.inc

PROMPT="${1:-}"

if [ -z "$PROMPT" ]; then
  echo "Usage: $0 'prompt text'" >&2
  exit 1
fi

SESSION_FILE="$NC_TALK_HERMES_SESSION_FILE"
BOT_NAME="${NC_TALK_BOT_NAME:-${NC_USER:-the configured bot user}}"

# Keep one Hermes session per configured Talk room.  The Talk token itself is
# not sent as a session identifier; only a SHA-256-derived opaque identifier is.
mkdir -p "$(dirname "$SESSION_FILE")"

if [ -s "$SESSION_FILE" ]; then
  HERMES_SESSION_ID="$(tr -d '\r\n' < "$SESSION_FILE")"
else
  ROOM_HASH="$(printf '%s' "$TALK_TOKEN" | sha256sum | awk '{print $1}')"
  HERMES_SESSION_ID="nc-talk-${ROOM_HASH}"
  printf '%s\n' "$HERMES_SESSION_ID" > "$SESSION_FILE"
fi

AUTH_HEADER=()
if [ -n "${HERMES_API_KEY:-}" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer $HERMES_API_KEY")
fi

HEADER_FILE="$(mktemp)"
BODY_FILE="$(mktemp)"
trap 'rm -f "$HEADER_FILE" "$BODY_FILE"' EXIT

HTTP_CODE="$(
  curl -sS \
    -D "$HEADER_FILE" \
    -o "$BODY_FILE" \
    -w '%{http_code}' \
    "${AUTH_HEADER[@]}" \
    -H "Content-Type: application/json" \
    -H "X-Hermes-Session-Id: $HERMES_SESSION_ID" \
      -d "$(
        jq -n \
          --arg model "$HERMES_MODEL" \
          --arg prompt "$PROMPT" \
          --arg bot_name "$BOT_NAME" \
          '{
            model: $model,
            messages: [
              {
                role: "user",
                content: (
                  "Visible bot name in this chat: " + $bot_name
                  + "\n\nCurrent message:\n"
                  + $prompt
                )
              }
            ]
          }'
      )" \
    "$HERMES_URL"
)"

# Hermes can return an effective continuation session ID (for example after
# context compression). Persist it so the next Talk message follows that session.
RETURNED_SESSION_ID="$(
  awk 'BEGIN { IGNORECASE=1 }
       /^X-Hermes-Session-Id:/ {
         sub(/^[^:]*:[[:space:]]*/, "");
         sub(/\r$/, "");
         value=$0
       }
       END { print value }' "$HEADER_FILE"
)"

if [ -n "$RETURNED_SESSION_ID" ]; then
  printf '%s\n' "$RETURNED_SESSION_ID" > "$SESSION_FILE"
fi

if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
  ERROR_MESSAGE="$(jq -r '.error.message // .message // empty' "$BODY_FILE" 2>/dev/null || true)"
  if [ -n "$ERROR_MESSAGE" ]; then
    echo "Hermes API error (HTTP $HTTP_CODE): $ERROR_MESSAGE" >&2
  else
    echo "Hermes API error (HTTP $HTTP_CODE)" >&2
    cat "$BODY_FILE" >&2
  fi
  exit 1
fi

ANSWER="$(jq -r '.choices[0].message.content // empty' "$BODY_FILE")"

if [ -z "$ANSWER" ]; then
  echo "Hermes API returned no assistant message." >&2
  cat "$BODY_FILE" >&2
  exit 1
fi

printf '%s\n' "$ANSWER"
