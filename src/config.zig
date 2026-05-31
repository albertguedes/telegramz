const std = @import("std");
const fs = std.fs;

pub const Config = struct {
    api_id: ?i32 = null,
    api_hash: ?[]const u8 = null,
    phone: ?[]const u8 = null,
    session_name: []const u8 = "default",
    database_directory: []const u8 = "",
    use_test_dc: bool = false,
    verbosity_level: i32 = 2,
    discovery_timeout_secs: u32 = 10,
};

pub fn getConfigDir() []const u8 {
    return "/.config/telegramz";
}

pub fn getDefaultConfigDir() []const u8 {
    if (std.posix.getenv("HOME")) |home| {
        var buf: [1024]u8 = undefined;
        return std.fmt.bufPrintZ(&buf, "{s}/.config/telegramz", .{home}) catch return "/.config/telegramz";
    }
    return "/.config/telegramz";
}

pub fn getDefaultSessionDir() []const u8 {
    if (std.posix.getenv("HOME")) |home| {
        var buf: [1024]u8 = undefined;
        return std.fmt.bufPrintZ(&buf, "{s}/.config/telegramz/sessions", .{home}) catch return "/.config/telegramz/sessions";
    }
    return "/.config/telegramz/sessions";
}

var session_buf: [1024]u8 = undefined;
pub fn getSessionDir(session_name: []const u8) []u8 {
    if (std.posix.getenv("HOME")) |home| {
        const result = std.fmt.bufPrintZ(&session_buf, "{s}/.config/telegramz/sessions/{s}", .{home, session_name}) catch return "";
        return result;
    }
    return "";
}

pub fn loadConfig() Config {
    const from_file = loadConfigFromFile();
    if (from_file.api_id != null and from_file.api_hash != null and from_file.phone != null) {
        return from_file;
    }
    return loadConfigFromEnv();
}

pub fn loadConfigFromEnv() Config {
    var config = Config{};
    const allocator = std.heap.page_allocator;

    if (std.posix.getenv("TELEGRAM_API_ID")) |val| {
        config.api_id = std.fmt.parseInt(i32, val, 10) catch null;
    }
    if (std.posix.getenv("TELEGRAM_API_HASH")) |val| {
        config.api_hash = allocator.dupe(u8, val) catch null;
    }
    if (std.posix.getenv("TELEGRAM_PHONE")) |val| {
        config.phone = allocator.dupe(u8, val) catch null;
    }
    if (std.posix.getenv("TELEGRAM_SESSION")) |val| {
        config.session_name = allocator.dupe(u8, val) catch "default";
    }
    if (std.posix.getenv("TELEGRAM_USE_TEST_DC")) |val| {
        config.use_test_dc = std.mem.eql(u8, val, "1") or std.mem.eql(u8, val, "true") or std.mem.eql(u8, val, "yes");
    }
    if (std.posix.getenv("TELEGRAM_VERBOSITY_LEVEL")) |val| {
        config.verbosity_level = std.fmt.parseInt(i32, val, 10) catch 2;
    }
    if (std.posix.getenv("TELEGRAM_DISCOVERY_TIMEOUT")) |val| {
        config.discovery_timeout_secs = std.fmt.parseInt(u32, val, 10) catch 10;
    }

    return config;
}

pub fn loadConfigFromFile() Config {
    var config = Config{};
    const allocator = std.heap.page_allocator;
    
    if (std.posix.getenv("HOME")) |home| {
        var config_path_buf: [1024]u8 = undefined;
        const config_path = std.fmt.bufPrintZ(&config_path_buf, "{s}/.config/telegramz/config", .{home}) catch return Config{};
        
        const file = fs.cwd().openFile(config_path, .{}) catch return Config{};
        defer file.close();
        
        const content = file.readToEndAlloc(allocator, 4096) catch return Config{};
        defer allocator.free(content);
        
        var start: usize = 0;
        while (start < content.len) {
            const end = std.mem.indexOf(u8, content[start..], "\n") orelse content.len;
            const line = content[start..start+end];
            start += end + 1;
            
            if (line.len == 0 or line[0] == '#') continue;
            
            if (std.mem.indexOf(u8, line, "=")) |idx| {
                const key = std.mem.trim(u8, line[0..idx], " \t");
                const value = std.mem.trim(u8, line[idx + 1..], " \t\"");

                if (std.mem.eql(u8, key, "api_id") or std.mem.eql(u8, key, "TELEGRAM_API_ID")) {
                    config.api_id = std.fmt.parseInt(i32, value, 10) catch null;
                } else if (std.mem.eql(u8, key, "api_hash") or std.mem.eql(u8, key, "TELEGRAM_API_HASH")) {
                    config.api_hash = allocator.dupe(u8, value) catch null;
                } else if (std.mem.eql(u8, key, "phone") or std.mem.eql(u8, key, "TELEGRAM_PHONE")) {
                    config.phone = allocator.dupe(u8, value) catch null;
                } else if (std.mem.eql(u8, key, "session") or std.mem.eql(u8, key, "SESSION_NAME")) {
                    config.session_name = allocator.dupe(u8, if (value.len > 0) value else "default") catch "default";
                } else if (std.mem.eql(u8, key, "use_test_dc") or std.mem.eql(u8, key, "USE_TEST_DC")) {
                    config.use_test_dc = std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "yes");
                } else if (std.mem.eql(u8, key, "verbosity_level") or std.mem.eql(u8, key, "VERBOSITY_LEVEL")) {
                    config.verbosity_level = std.fmt.parseInt(i32, value, 10) catch 2;
                } else if (std.mem.eql(u8, key, "discovery_timeout_secs") or std.mem.eql(u8, key, "DISCOVERY_TIMEOUT_SECS")) {
                    config.discovery_timeout_secs = std.fmt.parseInt(u32, value, 10) catch 10;
                }
            }
        }
    }
    
    return config;
}

pub fn saveConfigToFile(cfg: *const Config) !void {
    var home_buf: [512]u8 = undefined;
    const home = std.fmt.bufPrintZ(&home_buf, "{s}", .{
        std.posix.getenv("HOME") orelse "/home",
    }) catch return;

    var config_dir_buf: [1024]u8 = undefined;
    const config_dir = std.fmt.bufPrintZ(&config_dir_buf, "{s}/.config/telegramz", .{home}) catch return;

    fs.makeDirAbsolute(config_dir) catch |e| if (e != error.PathAlreadyExists) return e;

    var config_path_buf: [1024]u8 = undefined;
    const config_path = std.fmt.bufPrintZ(&config_path_buf, "{s}/config", .{config_dir}) catch return;

    const file = fs.cwd().createFile(config_path, .{}) catch return error.CreateFailed;
    defer file.close();

    var content_buf: [2048]u8 = undefined;
    const content = std.fmt.bufPrintZ(&content_buf,
        "# TelegramZ Configuration\napi_id={}\napi_hash={s}\nphone={s}\nsession={s}\nuse_test_dc={}\nverbosity_level={}\ndiscovery_timeout_secs={}\n",
        .{
            cfg.api_id orelse 0,
            cfg.api_hash orelse "",
            cfg.phone orelse "",
            cfg.session_name,
            @intFromBool(cfg.use_test_dc),
            cfg.verbosity_level,
            cfg.discovery_timeout_secs,
        }) catch return error.BufferOverflow;

    try file.writeAll(content);
}

pub fn ensureConfigDir() !void {
    const config_dir = getDefaultConfigDir();
    fs.makeDirAbsolute(config_dir) catch |e| if (e != error.PathAlreadyExists) return e;
    
    const session_dir = getDefaultSessionDir();
    fs.makeDirAbsolute(session_dir) catch |e| if (e != error.PathAlreadyExists) return e;
}

pub fn hasCredentials(cfg: *const Config) bool {
    return cfg.api_id != null and cfg.api_hash != null and cfg.phone != null;
}