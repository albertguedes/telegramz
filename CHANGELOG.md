# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-05-30

### Fixed

- **searchChatMessages**: Fixed `searchMessages` to use correct TDLib `searchChatMessages` API instead of global `searchMessages` which timed out
- **Auto-saved messages**: `search_messages` without `--chat-id` now automatically searches saved messages (was timing out)
- **Response parsing**: Fixed response type detection for `foundChatMessages` (was not recognized)

### Added

- **Date filters**: `search_messages` now supports `--min-date` and `--max-date` Unix timestamp filters
- **getSavedDialogs**: Added stub function (API not available in TDLib 1.8.61)
- **SCOPE.md**: Project scope documentation with TDLib limitations

### Changed

- **Search timeout**: Increased from 10s to 60s for search operations
- **getSavedMessages**: Now returns messages in chronological order (oldest first) with proper pagination params

## [0.1.0] - 2026-05-30

### Breaking Changes

- **Removed**: `get_messages` command (replaced by type-specific commands)
- Version bump to v0.1.0

### Added

- **New Commands**:
  - `get_contacts [--limit N]` - List contacts with info
  - `get_group_messages --chat-id ID [--limit N] [--from-id ID]` - Get messages from group
  - `get_channel_messages --chat-id ID [--limit N] [--from-id ID]` - Get messages from channel
  - `get_contact_messages --user-id ID [--limit N] [--from-id ID]` - Get messages from contact
- **Configuration Options**:
  - `discovery_timeout_secs` - Configurable timeout for user/chat discovery (default: 10s)
  - `use_test_dc` - Now respected (previously hardcoded to false)
  - `verbosity_level` - Persisted to config file
- **Bug Fixes**:
  - Fixed `toJson()` returning raw data instead of properly formatted JSON
  - Fixed `escapeJsonString()` not escaping newlines, tabs, and control characters
  - Fixed unsafe `g_engine.?` force unwrap that could cause panic
  - Fixed `searchMessages` ignoring `chat_id` parameter (now supports per-chat search)
  - Fixed flood wait handling only for code 420 (now handles codes 420-429)
- **Improvements**:
  - `getSavedMessages` now uses native TDLib `getSavedMessages` API
  - Config file now persisted after successful authentication
  - `getGroupMessages`/`getChannelMessages` support `from_id` for pagination
  - Newlines and special characters in JSON output are now properly escaped
- **Documentation**:
  - Added `docs/CONTRIBUTING.md` with development guidelines
- **Code Cleanup**:
  - Removed dead code (`initTDLib`, unused `AuthHandler` methods)
  - Removed TDLib-dependent tests that can't run in isolation

### Changed

- `get_groups` and `get_channels` now return structured info (not just IDs)
- Application version updated to v0.1.0 in TDLib parameters

## [0.0.1] - 2026-05-29

### Added

- Initial release
- 10 commands: get_dialogs, get_groups, get_channels, get_messages, get_saved_messages, send_message, search, search_messages, get_chat_info
- TDLib integration via C FFI
- JSON output format
- Session persistence support
- Config file support (~/.config/telegramz/config)
- Multi-distro package support (.deb, .rpm, .pkg.tar.zst, .ebuild, .apk)
- Documentation: README.md, USER_MANUAL.md, TECHNICAL.md

### Known Issues

- Authentication requires manual phone/code entry on first run
- ARM64 builds not yet available

### TODO

- [ ] ARM64 builds
- [ ] FreeBSD native compilation
- [ ] Launchpad PPA
- [ ] Copr (Fedora)
- [ ] AUR (Arch)
- [ ] Interactive REPL mode
- [ ] Webhook support
- [ ] Multi-account support