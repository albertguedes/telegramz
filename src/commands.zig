const std = @import("std");

pub const CommandResult = struct {
    ok: bool,
    data: ?[]const u8,
    err_msg: ?[]const u8,
    code: i32,
};

pub fn ok(data: []const u8) CommandResult {
    return CommandResult{
        .ok = true,
        .data = data,
        .err_msg = null,
        .code = 200,
    };
}

pub fn errorResult(msg: []const u8, code: i32) CommandResult {
    return CommandResult{
        .ok = false,
        .data = null,
        .err_msg = msg,
        .code = code,
    };
}

pub fn makeError(msg: []const u8, code: i32) CommandResult {
    return CommandResult{
        .ok = false,
        .data = null,
        .err_msg = msg,
        .code = code,
    };
}

pub fn toJson(res: CommandResult) []const u8 {
    if (res.ok) {
        if (res.data) |d| return formatOk(d);
        return "{\"ok\":true}";
    } else {
        return formatError(res.code, res.err_msg orelse "error");
    }
}

pub fn formatError(code: i32, msg: []const u8) []const u8 {
    var buf: [512]u8 = undefined;
    return std.fmt.bufPrintZ(&buf,
        "{{\"ok\":false,\"error\":\"{s}\",\"code\":{}}}",
        .{msg, code}) catch "{\"ok\":false,\"error\":\"buffer overflow\",\"code\":500}";
}

pub fn formatOk(data: []const u8) []const u8 {
    var escape_buf: [4096]u8 = undefined;
    var out_buf: [8192]u8 = undefined;
    const escaped = escapeJsonString(data,&escape_buf);
    return std.fmt.bufPrintZ(&out_buf,
        "{{\"ok\":true,\"data\":\"{s}\"}}",
        .{escaped}) catch "{\"ok\":false,\"error\":\"buffer overflow\",\"code\":500}";
}

fn escapeJsonString(data: []const u8, buf: []u8) []u8 {
    var j: usize = 0;
    for (data) |c| {
        switch (c) {
            '"' => {
                if (j + 2 > buf.len) return buf[0..j];
                buf[j] = '\\';
                buf[j + 1] = '"';
                j += 2;
            },
            '\\' => {
                if (j + 2 > buf.len) return buf[0..j];
                buf[j] = '\\';
                buf[j + 1] = '\\';
                j += 2;
            },
            '\n' => {
                if (j + 2 > buf.len) return buf[0..j];
                buf[j] = '\\';
                buf[j + 1] = 'n';
                j += 2;
            },
            '\r' => {
                if (j + 2 > buf.len) return buf[0..j];
                buf[j] = '\\';
                buf[j + 1] = 'r';
                j += 2;
            },
            '\t' => {
                if (j + 2 > buf.len) return buf[0..j];
                buf[j] = '\\';
                buf[j + 1] = 't';
                j += 2;
            },
            '/' => {
                if (j + 2 > buf.len) return buf[0..j];
                buf[j] = '\\';
                buf[j + 1] = '/';
                j += 2;
            },
            else => {
                if (c < 32) {
                    if (j + 6 > buf.len) return buf[0..j];
                    buf[j] = '\\';
                    buf[j + 1] = 'u';
                    buf[j + 2] = '0';
                    buf[j + 3] = '0';
                    const hex_chars = "0123456789ABCDEF";
                    const high_nibble = @as(u4, @intCast(c >> 4));
                    const low_nibble = @as(u4, @intCast(c & 0x0F));
                    buf[j + 4] = hex_chars[high_nibble];
                    buf[j + 5] = hex_chars[low_nibble];
                    j += 6;
                } else {
                    if (j + 1 > buf.len) return buf[0..j];
                    buf[j] = c;
                    j += 1;
                }
            },
        }
    }
    return buf[0..j];
}

pub fn formatSavedDialogs(data: []const u8) []const u8 {
    return data;
}
