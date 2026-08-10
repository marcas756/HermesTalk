if [ -z "${NC_TALK_DIR:-}" ]; then
  NC_TALK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

export NC_TALK_DIR

# Local log only. It is no longer injected into Hermes on every request.
export NC_TALK_HISTORY_FILE="${NC_TALK_HISTORY_FILE:-$NC_TALK_DIR/../nc_talk_history.txt}"
export NC_TALK_SYSTEM_PROMPT="${NC_TALK_SYSTEM_PROMPT:-$NC_TALK_DIR/nc_talk_system_prompt.txt}"
export NC_TALK_LAST_ID_FILE="${NC_TALK_LAST_ID_FILE:-$NC_TALK_DIR/../nc_talk_last_id.txt}"

# Stores the current Hermes continuation session ID. Hermes may rotate this ID
# after context compression, so nc_hermes_ask.sh updates the file from the
# X-Hermes-Session-Id response header.
export NC_TALK_HERMES_SESSION_FILE="${NC_TALK_HERMES_SESSION_FILE:-$NC_TALK_DIR/../nc_talk_hermes_session_id.txt}"

NC_TALK_LOCAL_SETTINGS="$NC_TALK_DIR/../nc_talk_settings.local.inc"

source "$NC_TALK_LOCAL_SETTINGS"
