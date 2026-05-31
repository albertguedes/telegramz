# TelegramZ

**Telegram CLI tool for Linux** — control Telegram from any script or application.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version: v0.1.0](https://img.shields.io/badge/Version-v0.1.0-blue.svg)](https://github.com/albertguedes/telegramz)

## Features

- **13 Commands**: get_dialogs, get_groups, get_channels, get_contacts, get_saved_messages, get_group_messages, get_channel_messages, get_contact_messages, send_message, search, search_messages, get_chat_info
- **User Account**: Full Telegram access (not bot)
- **JSON Output**: Easy integration with any language
- **Persistent Sessions**: Encrypted session storage
- **System Install**: `/usr/bin/telegramz`

## Installation

### From Binary (Recommended)

Download from [GitHub Releases](https://github.com/albertguedes/telegramz/releases):

```bash
# Debian/Ubuntu
sudo dpkg -i telegramz_*_amd64.deb

# Fedora/RHEL
sudo rpm -i telegramz-*.x86_64.rpm

# Arch
sudo pacman -U telegramz-*.pkg.tar.zst

# From source
tar -xzf telegramz-*.tar.gz
cd telegramz-*/
sudo make install
```

### Build from Source

```bash
git clone https://github.com/albertguedes/telegramz.git
cd telegramz
zig build -Drelease-safe
sudo make install
```

## Configuration

Create `~/.config/telegramz/config`:

```
api_id=your_api_id
api_hash=your_api_hash
phone=+5511999999999
session=default
use_test_dc=false
verbosity_level=2
discovery_timeout_secs=10
```

Or use environment variables:
```bash
export TELEGRAM_API_ID=your_id
export TELEGRAM_API_HASH=your_hash
export TELEGRAM_PHONE=+5511999999999
```

## Quick Start

```bash
# Get all dialogs
telegramz get_dialogs --limit 20

# Get groups
telegramz get_groups --limit 20

# Get messages from a group
telegramz get_group_messages --chat-id 123456789 --limit 50

# Get messages from a channel
telegramz get_channel_messages --chat-id 123456789 --limit 50

# Get messages from a contact
telegramz get_contact_messages --user-id 123456789 --limit 50

# Send a message
telegramz send_message --chat-id 123456789 --text "Hello!"

# Search public groups
telegramz search groups rust programming

# Search in a specific chat
telegramz search_messages --chat-id 123456789 --query "job" --limit 20

# Search in saved messages (auto-detected)
telegramz search_messages --query "job" --limit 20

# Search with date filters (Unix timestamps)
telegramz search_messages --chat-id 123456789 --query "job" --min-date 1704067200 --max-date 1735689600

# Get chat info
telegramz get_chat_info --chat-id 123456789
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `get_dialogs [--limit N]` | List all conversations |
| `get_groups [--limit N]` | List groups with info |
| `get_channels [--limit N]` | List channels with info |
| `get_contacts [--limit N]` | List contacts |
| `get_saved_messages [--limit N]` | Get saved messages |
| `get_group_messages --chat-id ID [--limit N] [--from-id ID]` | Get messages from group |
| `get_channel_messages --chat-id ID [--limit N] [--from-id ID]` | Get messages from channel |
| `get_contact_messages --user-id ID [--limit N] [--from-id ID]` | Get messages from contact |
| `send_message --chat-id ID --text "..." | Send message |
| `search <query>` | Search Telegram public directory |
| `search_messages [--chat-id ID] --query "..." [--limit N] [--min-date N] [--max-date N]` | Search in chats |
| `get_chat_info --chat-id ID` | Get chat details |

## JSON Output

All commands return JSON:

```json
// Success
{"ok":true,"data":"..."}

// Error
{"ok":false,"error":"message","code":400}
```

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](docs/CONTRIBUTING.md) for details.