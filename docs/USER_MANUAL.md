# TelegramZ - User Manual

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Quick Start](#quick-start)
4. [Commands Reference](#commands-reference)
5. [JSON Output](#json-output)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)

## Installation

### From Package

#### Debian/Ubuntu
```bash
sudo dpkg -i telegramz_*_amd64.deb
```

#### Fedora/RHEL
```bash
sudo rpm -i telegramz-*.x86_64.rpm
```

#### Arch Linux
```bash
sudo pacman -U telegramz-*.pkg.tar.zst
```

#### Gentoo
```bash
sudo ebuild telegramz-*.ebuild merge
```

### From Source

```bash
git clone https://github.com/albertguedes/telegramz.git
cd telegramz
zig build -Drelease-safe
sudo make install
```

## Configuration

### Config File

Create `~/.config/telegramz/config`:

```bash
TELEGRAM_API_ID=35293505
TELEGRAM_API_HASH=your_api_hash_here
TELEGRAM_PHONE=+5511999999999
SESSION_NAME=default
```

### Environment Variables

```bash
export TELEGRAM_API_ID=your_id
export TELEGRAM_API_HASH=your_hash
export TELEGRAM_PHONE=+5511999999999
```

### Permissions

```bash
chmod 600 ~/.config/telegramz/config
```

## Quick Start

1. Get credentials from [my.telegram.org](https://my.telegram.org)
2. Create config file
3. Run commands:

```bash
# List all dialogs
telegramz get_dialogs --limit 20

# Send a message
telegramz send_message --chat-id 123456789 --text "Hello world!"

# Search for groups
telegramz search groups rust programming
```

## Commands Reference

### get_dialogs

List all conversations (chats, groups, channels, saved messages).

```bash
telegramz get_dialogs [--limit N]
```

**Options:**
- `--limit`, `-l`: Maximum number of dialogs (default: 100)

### get_groups

List subscribed groups.

```bash
telegramz get_groups
```

### get_channels

List subscribed channels.

```bash
telegramz get_channels
```

### get_messages

Get messages from a specific chat.

```bash
telegramz get_messages --chat-id ID [--limit N] [--from-id ID]
```

**Options:**
- `--chat-id`: Chat ID (required)
- `--limit`, `-l`: Maximum messages (default: 20)
- `--from-id`: Start from message ID

### get_saved_messages

Get saved messages (Starred).

```bash
telegramz get_saved_messages [--limit N]
```

**Options:**
- `--limit`, `-l`: Maximum messages (default: 20)

### send_message

Send a text message.

```bash
telegramz send_message --chat-id ID --text "..." [--reply-to ID]
```

**Options:**
- `--chat-id`: Chat ID (required)
- `--text`, `-t`: Message text (required)
- `--reply-to`: Reply to message ID

### search

Search Telegram public directory.

```bash
telegramz search groups|channels|users <query>
```

**Examples:**
```bash
telegramz search groups rust programming
telegramz search channels open source
telegramz search users john doe
```

### search_messages

Search within subscribed chats. When `--chat-id` is not specified, searches saved messages.

```bash
telegramz search_messages --query "..." [--chat-id ID] [--limit N] [--min-date N] [--max-date N]
```

**Options:**
- `--query`, `-q`: Search query (required)
- `--chat-id`: Limit to specific chat (defaults to saved messages)
- `--limit`, `-l`: Maximum results (default: 20)
- `--min-date`: Filter messages from this Unix timestamp
- `--max-date`: Filter messages until this Unix timestamp

**Examples:**
```bash
# Search in saved messages
telegramz search_messages --query "job"

# Search in specific chat
telegramz search_messages --chat-id 123456789 --query "job"

# Search with date range (2024-01-01 to 2024-12-31)
telegramz search_messages --chat-id 123456789 --query "job" --min-date 1704067200 --max-date 1735689600
```

### get_chat_info

Get detailed information about a chat.

```bash
telegramz get_chat_info --chat-id ID
```

**Options:**
- `--chat-id`: Chat ID (required)

## JSON Output

All commands return JSON for easy parsing:

```json
// Success
{"ok":true,"data":{"dialogs":[...]}}

// Error
{"ok":false,"error":"Chat not found","code":404}
```

### Parse with jq

```bash
# Get first dialog name
telegramz get_dialogs | jq '.data.dialogs[0].title'

# Get message text
telegramz get_messages --chat-id 123 | jq '.data.messages[0].text'

# Check for errors
telegramz send_message --chat-id 123 --text "hi" | jq '.ok'
```

## Examples

### Get All Dialogs

```bash
telegramz get_dialogs --limit 50 | jq '.data.dialogs[] | .title'
```

### Send Message to Multiple Chats

```bash
for chat_id in 123456 789012 345678; do
  telegramz send_message --chat-id $chat_id --text "Hello!"
done
```

### Search and Get Chat Info

```bash
# Search for programming groups
telegramz search groups programming | jq -r '.data[].title'

# Get info about a specific group
telegramz get_chat_info --chat-id 123456789 | jq '.data.title'
```

## Troubleshooting

### "API credentials required"

Set `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `TELEGRAM_PHONE` in config or environment.

### "Session not found"

Create a new session by providing valid credentials.

### "Connection timeout"

Check your internet connection and try again.

### "Permission denied"

Ensure config file permissions: `chmod 600 ~/.config/telegramz/config`

## Getting Help

- GitHub Issues: https://github.com/albertguedes/telegramz/issues
- Documentation: https://albertguedes.github.io/telegramz