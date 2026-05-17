# HermesTalk - Private AI chat, routed through Nextcloud Talk via bash 

This implementation intentionally uses a small polling-based shell bridge instead of a full Nextcloud Talk bot integration. The goal is to get a private Hermes-backed assistant running quickly with minimal dependencies and without requiring a custom Nextcloud app or public webhook endpoint.

For a personal single-room setup, this approach is simple, transparent, and easy to debug. It can later be replaced by a native Talk bot webhook service or a small daemon if lower latency, stronger error handling, or multi-room support becomes necessary.

## Introduction

This project provides a lightweight bridge between Nextcloud Talk and the Hermes API, allowing a personal assistant to participate in a private Talk conversation through a regular text-message workflow. Incoming messages are polled from a configured Talk room, enriched with the visible sender name and recent local conversation history, forwarded to Hermes together with a system prompt, and the generated response is sent back into the same Talk chat. The integration deliberately keeps Nextcloud Talk as a transport channel only: the assistant can receive and answer text messages, but it does not have access to Nextcloud files, calendars, contacts, users, rooms, settings, or server-side bot functions.

## Other Solutions

I considered a few cleaner alternatives, but they were not practical for the first version.

A proper Nextcloud Talk bot/webhook integration would have been nicer, but I do not want to depend on bot support on the Nextcloud server side. 

A small Python/Go/Node daemon would be more maintainable, but would have taken too long to build properly (at least for me). 

Node-RED or n8n would also work, but they felt like overkill for this use case and would introduce another service that has to be hosted, configured, secured, updated, and monitored. A native Hermes Gateway integration might be possible, but I had no clear starting point for that.

So I chose the simple shell-script polling bridge. It is cheap, transparent, easy to debug, and good enough to get a private single-room Hermes assistant running through Nextcloud Talk. 

## Project File Overview

| File                                          | Short description                                                                                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `nc_talk/README.md`                           | Project documentation with setup, usage, and configuration notes.                                                                                 |
| `nc_talk/LICENSE.txt`                         | License text for the project.                                                                                                                     |
| `nc_talk/nc_hermes_ask.sh`                    | Sends the user message, recent history, and system prompt to the Hermes API and returns the assistant response.                                   |
| `nc_talk/nc_talk_rcv_loop.sh`                 | Main receive loop: polls Nextcloud Talk for new messages, ignores the bot’s own messages, calls Hermes, stores history, and sends the reply back. |
| `nc_talk/nc_talk_send.sh`                     | Sends a text message into the configured Nextcloud Talk room.                                                                                     |
| `nc_talk/nc_talk_settings.inc`                | Main configuration file loaded by the scripts. Usually includes shared settings and optionally local overrides.                                   |
| `nc_talk/nc_talk_settings.local.inc.template` | Template for local/private settings such as URLs, credentials, tokens, model name, and file paths.                                                |
| `nc_talk/nc_talk_system_prompt.txt`           | System prompt that defines the assistant’s role, behavior, limitations, and Nextcloud Talk boundaries.                                            |
| `nc_talk_history.txt`                         | Local conversation history used to give Hermes short-term context between messages.                                                               |
| `nc_talk_last_id.txt`                         | Stores the last processed Talk message ID so old messages are not handled repeatedly.                                                             |
| `nc_talk_settings.local.inc`                  | Local private configuration file with real instance-specific values; should not be committed to Git.                                              |


## Setting up `hermes-talk.service`

Create the user service file:

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/hermes-talk.service
```

Add:

```
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

Reload systemd and enable the service:

```bash
systemctl --user daemon-reload
systemctl --user enable hermes-talk.service
systemctl --user start hermes-talk.service
```

Requires= and After= ensure that hermes-talk.service starts with and after hermes-gateway.service.
PartOf= makes it follow the gateway lifecycle, so restarting or stopping the gateway also affects the Talk bridge.

Checking the setup

Check status:

```bash
systemctl --user status hermes-talk.service
```
Check that it is connected to the gateway:

```bash
systemctl --user list-dependencies --reverse hermes-gateway.service
```
You should see hermes-talk.service listed below hermes-gateway.service.

View logs:

```bash
journalctl --user -u hermes-talk.service -f
```

Show the installed service file:

```bash
systemctl --user cat hermes-talk.service
```

## Licensed under the BSD 3-Clause License.

This project is provided as-is, without warranty of any kind and without any guarantee that it will work for your setup. No support, maintenance, or operational responsibility is provided.

Read the code first, understand what it does, and use it only if you are comfortable with the implementation and the risks.



