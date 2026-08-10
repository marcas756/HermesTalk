# HermesTalk — Private AI chat through Nextcloud Talk

HermesTalk is a small Bash bridge that connects a private Nextcloud Talk room to a local or otherwise reachable Hermes-compatible Chat Completions API.

The project intentionally uses polling and ordinary Talk messages instead of a native Nextcloud Talk bot/webhook integration. The result is a lightweight setup with very few moving parts: Bash, `curl`, `jq`, Nextcloud Talk, and a running Hermes endpoint.

It is primarily intended for a personal, single-room assistant where simplicity and transparency are more important than low latency or large-scale multi-room support.

## How it works

The receive loop polls one configured Nextcloud Talk room for new text messages. Messages written by the configured bot account itself are ignored. For every new user message, the sender's visible display name is prepended and the resulting prompt is passed to `nc_hermes_ask.sh`.

`nc_hermes_ask.sh` sends the prompt to the configured Hermes Chat Completions endpoint. Conversation continuity is maintained with an opaque Hermes session ID stored locally in `nc_talk_hermes_session_id.txt`. On the first request, the script derives a room-specific ID from the Talk token using SHA-256. If Hermes returns a replacement `X-Hermes-Session-Id` header, for example after context compression, that ID is stored and used for the next request.

The generated assistant response is then posted back into the same Nextcloud Talk room.

Nextcloud Talk is used only as the transport channel. These scripts do not provide Hermes with direct access to Nextcloud files, calendars, contacts, users, rooms, settings, or other server-side Nextcloud functions.

## Request flow

```text
Nextcloud Talk room
        |
        |  poll for new messages
        v
nc_talk_rcv_loop.sh
        |
        |  "<sender name>: <message>"
        v
nc_hermes_ask.sh
        |
        |  POST /v1/chat/completions
        |  X-Hermes-Session-Id
        v
     Hermes
        |
        |  assistant response
        v
nc_talk_send.sh
        |
        v
Nextcloud Talk room
```

## Why a shell bridge?

A native Talk bot/webhook service would be cleaner for a larger installation, but it also requires suitable server-side bot support and a reachable webhook service.

A Python, Go, or Node daemon would provide more room for structured logging, retries, concurrency, and multi-room handling, but would add implementation and maintenance overhead.

Node-RED or n8n could also solve the integration problem, but they introduce another service that has to be hosted, configured, secured, updated, and monitored.

For a private single-room setup, the polling bridge is deliberately small, inspectable, and easy to modify.

## Requirements

The scripts expect:

- Bash
- `curl`
- `jq`
- `sha256sum`
- a Nextcloud account for the bot
- a Nextcloud app password for that account
- a Nextcloud Talk room token
- a reachable Hermes-compatible `/v1/chat/completions` endpoint
- optionally, a Hermes API key

For the service setup shown below, a user-level systemd installation is also required.

## Project files

A typical layout is:

```text
.
├── nc_talk
│   ├── LICENSE.txt
│   ├── README.md
│   ├── nc_hermes_ask.sh
│   ├── nc_talk_rcv_loop.sh
│   ├── nc_talk_send.sh
│   ├── nc_talk_settings.inc
│   ├── nc_talk_settings.local.inc.template
│   └── nc_talk_system_prompt.txt        # optional/project-specific
├── nc_talk_history.txt                  # optional local log/project-specific
├── nc_talk_last_id.txt
├── nc_talk_hermes_session_id.txt
└── nc_talk_settings.local.inc
```

| File | Purpose |
| --- | --- |
| `nc_talk/README.md` | Project documentation. |
| `nc_talk/LICENSE.txt` | BSD 3-Clause license. |
| `nc_talk/nc_hermes_ask.sh` | Sends one prompt to Hermes, manages the continuation session ID, and prints the assistant response. |
| `nc_talk/nc_talk_rcv_loop.sh` | Polls Talk, selects new user messages, calls Hermes, and sends the answer back. |
| `nc_talk/nc_talk_send.sh` | Posts a text message to the configured Talk room. |
| `nc_talk/nc_talk_settings.inc` | Shared configuration and default state-file paths; loads the local private settings file. |
| `nc_talk/nc_talk_settings.local.inc.template` | Template for instance-specific credentials and Hermes settings. |
| `nc_talk_last_id.txt` | Stores the newest processed Talk message ID. |
| `nc_talk_hermes_session_id.txt` | Stores the current Hermes continuation session ID. |
| `nc_talk_settings.local.inc` | Private local configuration. Do not commit this file. |

`nc_talk_history.txt` and `nc_talk_system_prompt.txt` may still exist in a local project layout, but the current request path does not inject them into Hermes on every message. Conversation continuity is handled by the Hermes session ID instead.

## Configuration

Copy the local settings template to the parent directory of `nc_talk`:

```bash
cp nc_talk/nc_talk_settings.local.inc.template nc_talk_settings.local.inc
```

Edit it and provide your values:

```bash
export NC_URL="https://<YOUR_NEXTCLOUD_INSTANCE>"
export NC_USER="<BOT_USER_ON_NEXTCLOUD>"
export NC_APP_PASSWORD="<APP_PASSWORD_FOR_BOTUSER>"
export TALK_TOKEN="<NEXTCLOUD_TALK_TOKEN>"

export HERMES_URL="http://127.0.0.1:8642/v1/chat/completions"
export HERMES_API_KEY="<HERMES_API_KEY_OR_EMPTY>"
export HERMES_MODEL="hermes-agent"
```

The shared `nc_talk_settings.inc` file determines its own directory and defines default paths for the local state files. The private settings file is then sourced from:

```text
../nc_talk_settings.local.inc
```

relative to the `nc_talk` directory.

Keep credentials and generated state files out of Git. The supplied `.gitignore` excludes the local settings file, history file, last-message state, `*.local.inc`, history-style text files, and backup files. If you store the Hermes session ID inside the repository, add `nc_talk_hermes_session_id.txt` to your local ignore rules as well.

## Make the scripts executable

```bash
chmod +x nc_talk/nc_hermes_ask.sh
chmod +x nc_talk/nc_talk_rcv_loop.sh
chmod +x nc_talk/nc_talk_send.sh
```

## Basic testing

Run these commands from the `nc_talk` directory because the scripts source `./nc_talk_settings.inc`.

Test sending a Talk message:

```bash
cd ~/nc_talk
./nc_talk_send.sh "HermesTalk test message"
```

Test Hermes directly through the bridge:

```bash
./nc_hermes_ask.sh "Hello from HermesTalk"
```

If both commands work, start the receive loop manually:

```bash
./nc_talk_rcv_loop.sh
```

The loop polls Talk every three seconds.

## Message handling behavior

The receive loop requests up to 20 Talk messages, sorts them by message ID, ignores messages from the configured bot account, and handles the first new comment after the saved `nc_talk_last_id.txt` value.

After every polling cycle, the newest message ID returned by Talk is written to the state file. This prevents already-seen Talk messages from being processed repeatedly.

Set the shell variable `DEBUG_ECHO=1` before starting the receive loop if you want received messages echoed and sent back as debug messages instead of being forwarded to Hermes.

Example:

```bash
DEBUG_ECHO=1 ./nc_talk_rcv_loop.sh
```

## Hermes session handling

The session file defaults to:

```text
../nc_talk_hermes_session_id.txt
```

On the first Hermes request for a room, the script creates an opaque session ID in the form:

```text
nc-talk-<sha256-of-talk-token>
```

The Talk token itself is not sent as the session identifier.

Every request includes:

```text
X-Hermes-Session-Id: <current-session-id>
```

If the response contains a new `X-Hermes-Session-Id`, the script persists it for the next message. Deleting the session file therefore starts a new local Hermes conversation identity on the next request.

## Running as a systemd user service

Create the service file:

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/hermes-talk.service
```

Example:

```ini
[Unit]
Description=Hermes Nextcloud Talk Bridge
After=hermes-gateway.service network-online.target
Requires=hermes-gateway.service
PartOf=hermes-gateway.service

[Service]
Type=simple
WorkingDirectory=/home/user/nc_talk
ExecStart=/home/user/nc_talk/nc_talk_rcv_loop.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Adjust `/home/user/nc_talk` to your actual installation path.

Reload systemd and enable the service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-talk.service
```

`Requires=` and `After=` make the Talk bridge depend on and start after `hermes-gateway.service`. `PartOf=` couples its lifecycle to the gateway, so stopping or restarting the gateway also affects the Talk bridge.

Check its status:

```bash
systemctl --user status hermes-talk.service
```

Check the reverse dependency:

```bash
systemctl --user list-dependencies --reverse hermes-gateway.service
```

Follow the logs:

```bash
journalctl --user -u hermes-talk.service -f
```

Show the installed unit:

```bash
systemctl --user cat hermes-talk.service
```

## Limitations

This implementation is intentionally simple. In particular:

- it is designed around one configured Talk room;
- polling introduces up to a few seconds of message latency;
- it does not use a native Nextcloud Talk bot webhook;
- it has no built-in retry queue or backoff strategy;
- it processes one selected new Talk message per polling iteration;
- Nextcloud is only a text transport and is not exposed to Hermes as a tool/API integration.

If you need multi-room routing, attachments, richer Nextcloud access, lower latency, stronger delivery guarantees, or more advanced observability, a small daemon or native bot integration is a better next step.

## Security notes

Treat `NC_APP_PASSWORD`, `TALK_TOKEN`, and `HERMES_API_KEY` as secrets.

Use a dedicated Nextcloud bot account with only the access it needs, protect `nc_talk_settings.local.inc`, and review the shell scripts before running them on your system.

The generated Hermes session ID is derived from the Talk token with SHA-256 so the raw Talk token is not used as the session identifier. This is an opaque identifier, not a replacement for protecting the original Talk token.

## License

Licensed under the BSD 3-Clause License. See `LICENSE.txt` for the full license text.

This project is provided as-is, without warranty of any kind and without any guarantee that it will work for your setup. No support, maintenance, or operational responsibility is provided.

Read the code first, understand what it does, and use it only if you are comfortable with the implementation and the risks.
