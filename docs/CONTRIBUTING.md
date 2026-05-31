# Contributing to TelegramZ

Thank you for your interest in contributing to TelegramZ!

## Development Setup

### Prerequisites

- **Zig 0.15+** - [Install from official website](https://ziglang.org/download/)
- **tdlib 1.8+** with `tdjson` shared library
- **GCC** or **Clang** compiler
- **pkg-config** for library detection

### On Gentoo

```bash
emerge -av dev-lang/zig
emerge -av dev-libs/tdjson
```

### On Debian/Ubuntu

```bash
apt install zig tdjson-dev pkg-config
```

### Build

```bash
git clone https://github.com/albertguedes/telegramz.git
cd telegramz
zig build
```

### Test

```bash
zig build
zig test src/commands_test.zig
zig test src/config_test.zig
zig test src/engine_test.zig
```

## Code Style

- Write clear, descriptive variable and function names
- Keep functions small and focused (single responsibility)
- Add error handling for all fallible operations
- Use `std.fmt.bufPrintZ` for string formatting in fixed buffers
- Prefer `try`/`catch` for error propagation
- Use `defer` for cleanup operations

## Architecture

```
src/
├── main.zig      # CLI entry point, argument parsing, command routing
├── engine.zig    # TDLib JSON request builders, response formatting
├── tdljson.zig   # TDLib C FFI wrapper
├── config.zig    # Configuration loading from file/env
├── auth.zig      # TDLib authentication state management
└── commands.zig  # Command result types and JSON formatting
```

### Thread Safety Warning

**Important**: `main.zig` uses global variables (`g_engine`, `g_format`) that are **not thread-safe**. This is acceptable for single-threaded CLI usage but means TelegramZ should not be used as a library in multithreaded applications.

## Testing

### Unit Tests

```bash
zig test src/commands_test.zig
zig test src/config_test.zig
zig test src/engine_test.zig
zig test src/tdljson_test.zig  # Requires live TDLib - skipped otherwise
```

### Integration Tests

```bash
./tests/run.sh
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes with passing tests
4. Update documentation if needed
5. Commit with clear messages (`git commit -m "Add feature: ..."`)
6. Push to your fork (`git push origin feature/my-feature`)
7. Open a Pull Request

## Commit Message Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

Example:
```
feat(engine): add getContacts function for listing contacts

Implements TDLib getContacts API call to retrieve user contacts list.
Also adds corresponding command handler in main.zig.
```

## Configuration Options

| Environment Variable | Config File Key | Default | Description |
|---------------------|-----------------|---------|-------------|
| `TELEGRAM_API_ID` | `api_id` | - | Telegram API ID (required) |
| `TELEGRAM_API_HASH` | `api_hash` | - | Telegram API Hash (required) |
| `TELEGRAM_PHONE` | `phone` | - | Phone number (required) |
| `TELEGRAM_SESSION` | `session` | `default` | Session name |
| `TELEGRAM_USE_TEST_DC` | `use_test_dc` | `false` | Use Telegram test data centers |
| `TELEGRAM_DISCOVERY_TIMEOUT` | `discovery_timeout_secs` | `10` | Timeout for user discovery |
| `TELEGRAM_VERBOSITY_LEVEL` | `verbosity_level` | `2` | TDLib log verbosity |

## Reporting Issues

Please include:
- Zig version (`zig version`)
- tdlib version
- Distribution and version
- Steps to reproduce
- Expected vs actual behavior
- Relevant log output (run with `--format=json` for machine-readable output)