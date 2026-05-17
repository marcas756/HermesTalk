#!/bin/bash
set -euo pipefail

source ./nc_talk_settings.inc

PROMPT="${1:-}"

if [ -z "$PROMPT" ]; then
  echo "Usage: $0 'prompt text'" >&2
  exit 1
fi

HISTORY_FILE=$NC_TALK_HISTORY_FILE 
HISTORY_LINES=$NC_TALK_HISTORY_LINES 
SYSTEM_PROMPT_FILE=$NC_TALK_SYSTEM_PROMPT
BOT_NAME="${NC_TALK_BOT_NAME:-${NC_USER:-the configured bot user}}"


if [ -f "$HISTORY_FILE" ]; then
  HISTORY="$(tail -n "$HISTORY_LINES" "$HISTORY_FILE")"
else
  HISTORY=""
fi

if [ -f "$SYSTEM_PROMPT_FILE" ]; then
  SYSTEM_PROMPT="$(cat "$SYSTEM_PROMPT_FILE")"
else
  SYSTEM_PROMPT="You are a helpful assistant." 
fi

AUTH_HEADER=()
if [ -n "${HERMES_API_KEY:-}" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer $HERMES_API_KEY")
fi

curl -sS \
  "${AUTH_HEADER[@]}" \
  -H "Content-Type: application/json" \
  -d "$(
    jq -n \
      --arg model "$HERMES_MODEL" \
      --arg system_prompt "$SYSTEM_PROMPT" \
      --arg history "$HISTORY" \
      --arg prompt "$PROMPT" \
      --arg bot_name "$BOT_NAME" \
      '{
        model: $model,
        messages: [
          {
            role: "system",
            content: $system_prompt
          },
          {
            role: "user",
            content: (
              "Visible bot name in this chat: " + $bot_name
              +"\n\nPrevious conversation history:\n"
              + $history
              + "\n\nCurrent message:\n"
              + $prompt
            )
          }
        ]
      }'
  )" \
  "$HERMES_URL" \
| jq -r '.choices[0].message.content'
