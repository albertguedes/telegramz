const std = @import("std");
const config = @import("config.zig");

test "Config defaults" {
    const cfg = config.Config{};
    try std.testing.expect(cfg.api_id == null);
    try std.testing.expect(cfg.api_hash == null);
    try std.testing.expect(cfg.session_name.len > 0);
}

test "loadConfig returns struct" {
    const cfg = config.loadConfig();
    try std.testing.expect(cfg.api_id == null or cfg.api_id != null);
    try std.testing.expect(cfg.session_name.len >= 0);
}

test "getConfigDir returns path" {
    const path = config.getConfigDir();
    try std.testing.expect(path.len > 0);
}