# Technical Documentation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     telegramz CLI                          │
└──────────────────────────┬──────────────────────────────────┘
                          │
┌──────────────────────────▼──────────────────────────────────┐
│                    src/main.zig                             │
│  - Argument parsing                                          │
│  - Command routing                                           │
│  - JSON input/output                                        │
└──────────────────────────┬──────────────────────────────────┘
                          │
┌──────────────────────────▼──────────────────────────────────┐
│                    src/engine.zig                            │
│  - Command builders                                        │
│  - Response handling                                        │
│  - TDLib request/response                                   │
└──────────────────────────┬──────────────────────────────────┘
                          │
┌──────────────────────────▼──────────────────────────────────┐
│                    src/tdljson.zig                           │
│  - TDLib C FFI wrapper                                      │
│  - td_json_client_* functions                              │
└──────────────────────────┬──────────────────────────────────┘
                          │
                          │ C FFI
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    libtdjson.so                             │
│  - TDLib JSON interface                                     │
└──────────────────────────┬──────────────────────────────────┘
                          │
                          │ MTProto
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Telegram Cloud                          │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
telegramz/
├── build.zig              # Zig build manifest
├── src/
│   ├── main.zig           # CLI entry, argument parsing
│   ├── engine.zig        # Core Telegram engine
│   ├── tdljson.zig       # TDLib C FFI wrapper
│   ├── config.zig        # Configuration loading
│   ├── auth.zig           # Authentication handler
│   └── commands.zig       # Result formatting
├── packages/             # Distribution packages
│   ├── deb/
│   ├── rpm/
│   ├── arch/
│   ├── gentoo/
│   └── apk/
└── docs/
    ├── USER_MANUAL.md
    ├── TECHNICAL.md
    └── CHANGELOG.md
```

## Build System

### Requirements

- Zig 0.15+
- tdlib 1.8+ with tdjson shared library
- GCC or Clang
- pkg-config

### Build Commands

```bash
# Debug build
zig build

# Release build
zig build -Drelease-safe

# Install
sudo make install

# Clean
zig build clean
```

## TDLib Integration

TelegramZ uses the `td_json_client_*` C interface for TDLib:

| Function | Purpose |
|----------|---------|
| `td_json_client_create()` | Create new client |
| `td_json_client_send(client, json)` | Send request |
| `td_json_client_receive(client, timeout)` | Receive response |
| `td_json_client_execute(client, json)` | Synchronous execute |
| `td_json_client_destroy(client)` | Destroy client |

### Request Format

All requests are JSON-serialized TDLib API objects:

```json
{"@type": "functionName", "param1": "value1", "@extra": "id"}
```

### Response Format

Responses include `@type` field and `@extra` matching the request.

## Configuration

### Config File: `~/.config/telegramz/config`

```
TELEGRAM_API_ID=35293505
TELEGRAM_API_HASH=your_hash
TELEGRAM_PHONE=+5511999999999
SESSION_NAME=default
```

### Environment Variables

- `TELEGRAM_API_ID`: API ID from my.telegram.org
- `TELEGRAM_API_HASH`: API Hash from my.telegram.org
- `TELEGRAM_PHONE`: Phone number with country code

### Session Directory

Sessions stored in: `~/.config/telegramz/sessions/`

## API Reference

### CLI Usage

```bash
telegramz [command] [options]
```

### Commands

| Command | Description |
|---------|-------------|
| `get_dialogs [--limit N]` | List all dialogs |
| `get_groups` | List groups |
| `get_channels` | List channels |
| `get_messages --chat-id ID [--limit N] [--from-id ID]` | Get messages |
| `get_saved_messages [--limit N]` | Get saved messages |
| `send_message --chat-id ID --text "..." [--reply-to ID]` | Send message |
| `search groups\|channels\|users <query>` | Search public |
| `search_messages --query "..." [--chat-id ID] [--limit N]` | Search local |
| `get_chat_info --chat-id ID` | Get chat info |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Submit pull request

## License

MIT License - See LICENSE file