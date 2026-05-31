const std = @import("std");
const fs = std.fs;
const Thread = std.Thread;
const ChildProcess = std.process.Child;
const tdljson = @import("tdljson.zig");
const config = @import("config.zig");
const auth = @import("auth.zig");
const engine = @import("engine.zig");
const commands = @import("commands.zig");

var g_engine: ?*engine.Engine = null;
var g_format: engine.Format = .text;

fn cleanup() void {
    if (g_engine) |e| {
        e.destroy();
        g_engine = null;
    }
}

fn log(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrintZ(&buf, fmt, args) catch return;
    fs.File.stderr().writeAll(msg) catch {};
}

fn promptInput(prompt_text: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    log("{s}: ", .{prompt_text});

    var buf: [512]u8 = undefined;
    const len = try fs.File.stdin().read(&buf);
    if (len == 0) return error.EOF;

    const trimmed = std.mem.trim(u8, buf[0..len], "\r\n ");
    return try allocator.dupe(u8, trimmed);
}

fn promptSecret(prompt_text: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    log("{s}: ", .{prompt_text});

    var buf: [512]u8 = undefined;
    const len = try fs.File.stdin().read(&buf);
    if (len == 0) return error.EOF;

    const trimmed = std.mem.trim(u8, buf[0..len], "\r\n ");
    return try allocator.dupe(u8, trimmed);
}

fn setupInteractive(cfg: *config.Config) !void {
    log("\n=== TelegramZ Interactive Setup ===\n\n", .{});

    const allocator = std.heap.page_allocator;

    cfg.phone = try promptInput("Phone number (e.g. +5511999999999)", allocator);

    const api_id_str = try promptInput("API ID (from https://my.telegram.org)", allocator);
    cfg.api_id = std.fmt.parseInt(i32, api_id_str, 10) catch return error.InvalidInput;

    cfg.api_hash = try promptInput("API Hash (from https://my.telegram.org)", allocator);

    const session_raw = try promptInput("Session name (default: default)", allocator);
    if (session_raw.len > 0) {
        cfg.session_name = session_raw;
    } else {
        cfg.session_name = "default";
    }

    log("\n", .{});
}

fn authLoginFlow(cfg: *config.Config, client: *tdljson.TelegramClient) !void {
    log("\n=== Connecting to Telegram ===\n\n", .{});

    log("Waiting for authorization state (60s timeout)...\n", .{});

    const max_wait_secs: f64 = 60;
    const start = std.time.timestamp();
    var phone_sent = false;
    var code_sent = false;
    var password_sent = false;

    const allocator = std.heap.page_allocator;

    while (@as(i64, std.time.timestamp()) - start < @as(i64, @intFromFloat(max_wait_secs))) {
        if (client.receive(1.0)) |resp| {
            if (std.mem.indexOf(u8, resp, "authorizationStateWaitTdlibParameters")) |_| {
                log("Sending setTdlibParameters...\n", .{});

                const home = std.posix.getenv("HOME") orelse "/home";
                const session_name: []const u8 = cfg.session_name;
                const api_hash_val: []const u8 = cfg.api_hash orelse "";
                const api_id_val = cfg.api_id orelse 0;

                var params_buf: [4096]u8 = undefined;
                const params_json = std.fmt.bufPrintZ(&params_buf,
                    "{{\"@type\":\"setTdlibParameters\",\"@extra\":\"init\",\"use_test_dc\":{},\"database_directory\":\"{s}/.config/telegramz/sessions/{s}\",\"files_directory\":\"{s}/.config/telegramz/sessions/{s}/files\",\"use_file_database\":true,\"use_chat_info_database\":true,\"use_message_database\":true,\"use_secret_chats\":false,\"api_id\":{},\"api_hash\":\"{s}\",\"system_language_code\":\"en\",\"device_model\":\"TelegramZ/0.1.0\",\"system_version\":\"Linux\",\"application_version\":\"0.1.0\"}}",
                    .{@intFromBool(cfg.use_test_dc), home, session_name, home, session_name, api_id_val, api_hash_val}) catch {
                    log("JSON buffer overflow\n", .{});
                    return error.AuthFailed;
                };

                log("Params JSON: {s}\n", .{params_json});
                client.send(params_json);
            } else if (std.mem.indexOf(u8, resp, "authorizationStateWaitEncryptionKey")) |_| {
                log("Sending setDatabaseEncryptionKey...\n", .{});
                var key_buf: [512]u8 = undefined;
                const key_json = std.fmt.bufPrintZ(&key_buf,
                    "{{\"@type\": \"setDatabaseEncryptionKey\", \"@extra\": \"key\", \"new_encryption_key\": \"\"}}",
                    .{}) catch unreachable;
                client.send(key_json);
            } else if (std.mem.indexOf(u8, resp, "authorizationStateWaitPhoneNumber")) |_| {
                log("Phone number required...\n", .{});
                const phone = cfg.phone orelse "";
                var json_buf: [512]u8 = undefined;
                const json = std.fmt.bufPrintZ(&json_buf,
                    "{{\"@type\": \"setAuthenticationPhoneNumber\", \"phone_number\": \"{s}\"}}",
                    .{phone}) catch unreachable;
                client.send(json);
                phone_sent = true;
                log("Phone sent.\n", .{});
            } else if (std.mem.indexOf(u8, resp, "authorizationStateWaitCode")) |_| {
                log("SMS code required...\n", .{});
                const code = try promptSecret("Enter SMS code", allocator);
                defer allocator.free(code);
                var code_buf: [256]u8 = undefined;
                const code_json = std.fmt.bufPrintZ(&code_buf,
                    "{{\"@type\": \"checkAuthenticationCode\", \"code\": \"{s}\"}}",
                    .{code}) catch unreachable;
                client.send(code_json);
                code_sent = true;
                log("Code sent.\n", .{});
            } else if (std.mem.indexOf(u8, resp, "authorizationStateWaitPassword")) |_| {
                log("2FA password required...\n", .{});
                const password = try promptSecret("Enter 2FA password", allocator);
                defer allocator.free(password);
                var pwd_buf: [512]u8 = undefined;
                const pwd_json = std.fmt.bufPrintZ(&pwd_buf,
                    "{{\"@type\": \"checkAuthenticationPassword\", \"password\": \"{s}\"}}",
                    .{password}) catch unreachable;
                client.send(pwd_json);
                password_sent = true;
                log("Password sent.\n", .{});
            } else if (std.mem.indexOf(u8, resp, "authorizationStateReady")) |_| {
                log("\n=== Authentication successful! ===\n\n", .{});
                config.saveConfigToFile(cfg) catch {
                    log("Warning: Could not save config to file\n", .{});
                };
                return;
            } else if (std.mem.indexOf(u8, resp, "authorizationStateClosed")) |_| {
                log("Authorization closed.\n", .{});
                return error.AuthFailed;
            } else if (std.mem.indexOf(u8, resp, "\"@type\":\"error\"")) |_| {
                log("TDLib error: {s}\n", .{resp});

                if (std.mem.indexOf(u8, resp, "\"code\":")) |code_pos| {
                    const code_start = code_pos + 6;
                    var code_end = code_start;
                    while (code_end < resp.len and resp[code_end] >= '0' and resp[code_end] <= '9') : (code_end += 1) {}
                    if (code_end > code_start) {
                        const code = std.fmt.parseInt(i32, resp[code_start..code_end], 10) catch 0;
                        if (code >= 420 and code <= 429) {
                            if (std.mem.indexOf(u8, resp, "FLOOD_WAIT_")) |p| {
                                const after_underscore = resp[p + 11..];
                                var wait_secs: u64 = 0;
                                var multiplier: u64 = 1;
                                var k: usize = 0;
                                while (k < after_underscore.len and after_underscore[k] >= '0' and after_underscore[k] <= '9') : (k += 1) {}
                                var m = k;
                                while (m > 0) : (m -= 1) {
                                    wait_secs += (after_underscore[m - 1] - '0') * multiplier;
                                    multiplier *= 10;
                                }
                                var wait_buf: [64]u8 = undefined;
                                const wait_str = std.fmt.bufPrintZ(&wait_buf, "Flood wait: {} seconds. Waiting...", .{wait_secs}) catch "Flood wait error";
                                log("{s}\n", .{wait_str});
                                Thread.sleep(wait_secs * std.time.ns_per_s);
                                log("Flood wait complete. Continuing...\n", .{});
                            }
                        }
                    }
                }
            }
        }
    }

    log("Timeout waiting for auth.\n", .{});
    return error.AuthTimeout;
}

pub fn main() !void {
    tdljson.disableTDLibLogging();

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len >= 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        try fs.File.stderr().writeAll("telegramz - Telegram CLI tool v0.1.0\n");
        try fs.File.stderr().writeAll("Usage: telegramz [command] [options]\n");
        try fs.File.stderr().writeAll("Commands:\n");
        try fs.File.stderr().writeAll("  get_dialogs [--limit N]\n");
        try fs.File.stderr().writeAll("  get_groups [--limit N]\n");
        try fs.File.stderr().writeAll("  get_channels [--limit N]\n");
        try fs.File.stderr().writeAll("  get_contacts [--limit N]\n");
        try fs.File.stderr().writeAll("  get_saved_messages [--limit N] [--list]\n");
        try fs.File.stderr().writeAll("  get_group_messages --chat-id ID [--limit N] [--from-id ID]\n");
        try fs.File.stderr().writeAll("  get_channel_messages --chat-id ID [--limit N] [--from-id ID]\n");
        try fs.File.stderr().writeAll("  get_contact_messages --user-id ID [--limit N] [--from-id ID]\n");
        try fs.File.stderr().writeAll("  send_message --chat-id ID --text \"...\"\n");
        try fs.File.stderr().writeAll("  search <query>\n");
        try fs.File.stderr().writeAll("  search_messages [--chat-id ID] --query \"...\" [--limit N]\n");
        try fs.File.stderr().writeAll("  get_chat_info --chat-id ID\n");
        try fs.File.stderr().writeAll("\nFormat options:\n");
        try fs.File.stderr().writeAll("  --format=text  Human-readable (default)\n");
        try fs.File.stderr().writeAll("  --format=json  JSON output\n");
        try fs.File.stderr().writeAll("  --format=raw   Raw TDLib JSON\n");
        try fs.File.stderr().writeAll("\nEnvironment variables:\n");
        try fs.File.stderr().writeAll("  TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_PHONE\n");
        try fs.File.stderr().writeAll("  TELEGRAM_SESSION, TELEGRAM_USE_TEST_DC, TELEGRAM_DISCOVERY_TIMEOUT\n");
        return;
    }

    var i: usize = 1;
    while (i < args.len and std.mem.startsWith(u8, args[i], "--format=")) {
        const fmt_str = args[i][9..];
        if (std.mem.eql(u8, fmt_str, "text")) g_format = .text
        else if (std.mem.eql(u8, fmt_str, "json")) g_format = .json
        else if (std.mem.eql(u8, fmt_str, "raw")) g_format = .raw;
        i += 1;
    }

    try config.ensureConfigDir();

    var cfg = config.loadConfig();

    const client = try tdljson.TelegramClient.create();
    defer client.destroy();

    if (!config.hasCredentials(&cfg)) {
        log("\n=== TelegramZ Login ===\n\n", .{});
        log("No credentials found. Let's set up your account.\n\n", .{});

        try setupInteractive(&cfg);

        authLoginFlow(&cfg, client) catch |e| {
            log("Authentication failed: {s}\n", .{@errorName(e)});
            return;
        };
    } else {
        log("\n=== TelegramZ ===\n", .{});
        log("Using saved credentials...\n", .{});

        authLoginFlow(&cfg, client) catch |e| {
            log("Authentication failed: {s}\n", .{@errorName(e)});
            return;
        };
    }

    const eng = try engine.Engine.createWithClient(&cfg, client);
    g_engine = eng;
    errdefer cleanup();

    if (args.len < 2) {
        log("\nConnected! TelegramZ ready.\n", .{});
        log("Commands: get_dialogs, get_messages, send_message, search, etc.\n", .{});
        log("Run 'telegramz <command>' to use.\n", .{});
        return;
    }

    const cmd = args[i];
    const cmd_args = args[i + 1 ..];

    const result = parseAndExecute(cmd, cmd_args) catch |e| {
        try fs.File.stderr().writeAll(commands.formatError(500, @errorName(e)));
        return;
    };

    const json_out = commands.toJson(result);
    if (g_engine) |engineInstance| {
        const formatted = engineInstance.formatResponse(json_out, g_format);
        const stdout_fd: std.posix.fd_t = 1;
        _ = std.posix.write(stdout_fd, formatted) catch 0;
    } else {
        try fs.File.stderr().writeAll(commands.formatError(401, "Not connected"));
    }
}

fn receiveUntilType(client: *tdljson.TelegramClient, expected_type: []const u8, timeout_secs: f64) ?[]const u8 {
    const deadline = std.time.timestamp() + @as(i64, @intFromFloat(timeout_secs));
    var count: u32 = 0;
    var search_buf: [64]u8 = undefined;
    const search_pattern = std.fmt.bufPrintZ(&search_buf, "\"@type\":\"{s}\"", .{expected_type}) catch return null;
    while (std.time.timestamp() < deadline) {
        if (client.receive(0.5)) |resp| {
            count += 1;
            if (std.mem.indexOf(u8, resp, search_pattern) != null and
                std.mem.indexOf(u8, resp, "\"@type\":\"update") == null) {
                return resp;
            }
        }
    }
    return null;
}

fn parseAndExecute(cmd: []const u8, args: []const []const u8) !commands.CommandResult {
    if (g_engine == null) {
        return commands.errorResult("Not connected. Run telegramz first.", 401);
    }
    const eng = g_engine.?;

    if (std.mem.eql(u8, cmd, "get_dialogs")) {
        const json = eng.getDialogs(100, "");
        eng.send(json);
        if (receiveUntilType(eng.client, "chats", 10.0)) |resp| {
            return commands.ok(resp);
        }
        if (receiveUntilType(eng.client, "chats", 5.0)) |resp| {
            return commands.ok(resp);
        }
        return commands.errorResult("No response from Telegram", 504);
    }

    if (std.mem.eql(u8, cmd, "get_saved_messages")) {
        var limit: u32 = 10;
        var list_mode: bool = false;
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--list")) {
                list_mode = true;
            } else if (std.mem.eql(u8, args[i], "--limit") and i + 1 < args.len) {
                limit = std.fmt.parseInt(u32, args[i + 1], 10) catch 10;
                i += 1;
            }
        }
        const json = eng.getSavedMessages(limit);
        eng.send(json);
        const deadline = std.time.timestamp() + 30;
        while (std.time.timestamp() < deadline) {
            if (eng.receive(0.5)) |resp| {
                if (std.mem.indexOf(u8, resp, "\"@type\":\"update") == null) {
                    return commands.ok(resp);
                }
            }
        }
        return commands.errorResult("No response from Telegram", 504);
    }

    if (std.mem.eql(u8, cmd, "send_message")) {
        var chat_id: i64 = -1;
        var text: []const u8 = "";
        var reply_to: ?i64 = null;
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--chat-id")) {
                if (i + 1 < args.len) {
                    chat_id = std.fmt.parseInt(i64, args[i + 1], 10) catch -1;
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "--text") or std.mem.eql(u8, args[i], "-t")) {
                if (i + 1 < args.len) {
                    text = args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "--reply-to")) {
                if (i + 1 < args.len) {
                    reply_to = std.fmt.parseInt(i64, args[i + 1], 10) catch null;
                    i += 1;
                }
            }
        }
        if (chat_id < 0) {
            return commands.errorResult("Missing --chat-id", 400);
        }
        if (text.len == 0) {
            return commands.errorResult("Missing --text", 400);
        }
        const json = eng.sendMessage(chat_id, text, reply_to);
        eng.send(json);
        if (receiveUntilType(eng.client, "message", 10.0)) |resp| {
            return commands.ok(resp);
        }
        return commands.errorResult("No response from Telegram", 504);
    }

    if (std.mem.eql(u8, cmd, "search")) {
        var query: []const u8 = "";
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            if (args[i].len > 0 and args[i][0] != '-') {
                query = args[i];
            }
        }
        if (query.len == 0) {
            return commands.errorResult("Missing search query", 400);
        }
        const json = eng.searchPublicChats(query);
        eng.send(json);
        if (receiveUntilType(eng.client, "chats", 10.0)) |resp| {
            return commands.ok(resp);
        }
        return commands.errorResult("No response from Telegram", 504);
    }

    if (std.mem.eql(u8, cmd, "search_messages")) {
        var query: []const u8 = "";
        var limit: u32 = 20;
        var chat_id: i64 = 0;
        var min_date: i64 = 0;
        var max_date: i64 = 0;
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--query") or std.mem.eql(u8, args[i], "-q")) {
                if (i + 1 < args.len) {
                    query = args[i + 1];
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "--limit") or std.mem.eql(u8, args[i], "-l")) {
                if (i + 1 < args.len) {
                    limit = std.fmt.parseInt(u32, args[i + 1], 10) catch 20;
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "--chat-id")) {
                if (i + 1 < args.len) {
                    chat_id = std.fmt.parseInt(i64, args[i + 1], 10) catch 0;
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "--min-date")) {
                if (i + 1 < args.len) {
                    min_date = std.fmt.parseInt(i64, args[i + 1], 10) catch 0;
                    i += 1;
                }
            } else if (std.mem.eql(u8, args[i], "--max-date")) {
                if (i + 1 < args.len) {
                    max_date = std.fmt.parseInt(i64, args[i + 1], 10) catch 0;
                    i += 1;
                }
            }
        }
        if (query.len == 0) {
            return commands.errorResult("Missing --query", 400);
        }
        if (chat_id == 0) {
            chat_id = eng.saved_messages_chat_id;
        }
        const json = eng.searchMessages(query, limit, chat_id, min_date, max_date);
        eng.send(json);
        const deadline = std.time.timestamp() + 60;
        while (std.time.timestamp() < deadline) {
            if (eng.receive(0.5)) |resp| {
                if (std.mem.startsWith(u8, resp, "{\"@type\":\"error\"")) {
                    return commands.ok(resp);
                }
                if (std.mem.indexOf(u8, resp, "\"@type\":\"foundChatMessages") != null or
                    std.mem.indexOf(u8, resp, "\"@type\":\"messages\"") != null) {
                    return commands.ok(resp);
                }
            }
        }
        return commands.errorResult("No response from Telegram", 504);
    }

    return commands.errorResult("Unknown command", 404);
}