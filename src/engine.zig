const std = @import("std");
const tdljson = @import("tdljson.zig");
const config = @import("config.zig");
const auth = @import("auth.zig");

var json_buffer: [8192]u8 = undefined;
var text_buffer: [65536]u8 = undefined;

pub const Format = enum {
    text,
    json,
    raw,
};

const MessageType = enum {
    text,
    video,
    photo,
    document,
    audio,
    sticker,
    animation,
    voice_note,
    location,
    contact,
    unknown,
};

const ParsedMessage = struct {
    id: i64,
    chat_id: i64,
    user_id: i64,
    date: i64,
    msg_type: MessageType,
    text_content: [512]u8,
    text_len: usize,
    media_size: i64,
    media_width: i32,
    media_height: i32,
    media_duration: i32,
    file_name: [256]u8,
    file_name_len: usize,
    emoji: [32]u8,
    emoji_len: usize,
};

pub const Engine = struct {
    client: *tdljson.TelegramClient,
    auth_handler: *auth.AuthHandler,
    config: *const config.Config,
    saved_messages_chat_id: i64,

    pub fn create(cfg: *const config.Config) !*Engine {
        const client = try tdljson.TelegramClient.create();
        return createWithClient(cfg, client);
    }

    pub fn createWithClient(cfg: *const config.Config, client: *tdljson.TelegramClient) !*Engine {
        var eng = try std.heap.page_allocator.create(Engine);
        eng.* = Engine{
            .client = client,
            .auth_handler = undefined,
            .config = cfg,
            .saved_messages_chat_id = 0,
        };
        eng.auth_handler = try auth.AuthHandler.init(client, cfg);
        try eng.discoverSavedMessagesChat();
        return eng;
    }

    fn discoverSavedMessagesChat(self: *Engine) !void {
        var empty_count: u32 = 0;
        while (empty_count < 3) {
            if (self.client.receive(0.2)) |_| {
                empty_count = 0;
            } else {
                empty_count += 1;
            }
        }
        self.client.send("{\"@type\":\"getMe\",\"@extra\":\"me_request\"}");
        const deadline = std.time.timestamp() + 10;
        while (std.time.timestamp() < deadline) {
            if (self.client.receive(0.5)) |resp| {
                if (std.mem.indexOf(u8, resp, "@extra\":\"me_request\"") != null and
                    std.mem.indexOf(u8, resp, "\"@type\":\"user\"") != null) {
                    var i: usize = 0;
                    while (i < resp.len - 5) : (i += 1) {
                        if (std.mem.eql(u8, resp[i..i+5], "\"id\":")) {
                            i += 5;
                            while (i < resp.len and resp[i] == ' ') : (i += 1) {}
                            var end: usize = i;
                            while (end < resp.len and resp[end] >= '0' and resp[end] <= '9') : (end += 1) {}
                            if (end > i) {
                                const id_str = resp[i..end];
                                self.saved_messages_chat_id = std.fmt.parseInt(i64, id_str, 10) catch 0;
                                return;
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn send(self: *Engine, json_request: []const u8) void {
        self.client.send(json_request);
    }

    pub fn receive(self: *Engine, timeout_secs: f64) ?[]const u8 {
        return self.client.receive(timeout_secs);
    }

    pub fn destroy(self: *Engine) void {
        self.client.destroy();
        std.heap.page_allocator.destroy(self);
    }

    fn findField(json: []const u8, field_start: []const u8) ?usize {
        if (std.mem.indexOf(u8, json, field_start)) |idx| {
            return idx + field_start.len;
        }
        return null;
    }

    fn skipWhitespace(json: []const u8, start: usize) usize {
        var i = start;
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}
        return i;
    }

    fn parseInt(json: []const u8, start: usize) i64 {
        const i = skipWhitespace(json, start);
        var end = i;
        while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
        if (end > i) {
            return std.fmt.parseInt(i64, json[i..end], 10) catch 0;
        }
        return 0;
    }

    fn parseString(json: []const u8, start: usize, buf: []u8) []const u8 {
        var i = skipWhitespace(json, start);
        if (i >= json.len or json[i] != '"') return "";
        i += 1;
        var j: usize = 0;
        while (i < json.len and json[i] != '"' and j < buf.len) : (j += 1) {
            if (json[i] == '\\' and i + 1 < json.len) {
                i += 1;
            }
            buf[j] = json[i];
            i += 1;
        }
        return buf[0..j];
    }

    fn detectMessageType(json: []const u8) MessageType {
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageText\"") != null) return .text;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageVideo\"") != null) return .video;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messagePhoto\"") != null) return .photo;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageDocument\"") != null) return .document;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageAudio\"") != null) return .audio;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageSticker\"") != null) return .sticker;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageAnimation\"") != null) return .animation;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageVoiceNote\"") != null) return .voice_note;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageLocation\"") != null) return .location;
        if (std.mem.indexOf(u8, json, "\"@type\":\"messageContact\"") != null) return .contact;
        return .unknown;
    }

    fn parseMessageFromJson(msg_json: []const u8) ParsedMessage {
        var parsed = ParsedMessage{
            .id = 0, .chat_id = 0, .user_id = 0, .date = 0, .msg_type = .unknown,
            .text_content = undefined, .text_len = 0,
            .media_size = 0, .media_width = 0, .media_height = 0, .media_duration = 0,
            .file_name = undefined, .file_name_len = 0,
            .emoji = undefined, .emoji_len = 0,
        };

        const id_pos = findField(msg_json, "\"id\":");
        if (id_pos) |p| parsed.id = parseInt(msg_json, p);

        const chat_pos = findField(msg_json, "\"chat_id\":");
        if (chat_pos) |p| parsed.chat_id = parseInt(msg_json, p);

        const user_pos = findField(msg_json, "\"user_id\":");
        if (user_pos) |p| parsed.user_id = parseInt(msg_json, p);

        const date_pos = findField(msg_json, "\"date\":");
        if (date_pos) |p| parsed.date = parseInt(msg_json, p);

        parsed.msg_type = detectMessageType(msg_json);

        switch (parsed.msg_type) {
            .text => {
                const text_pos = findField(msg_json, "\"text\":\"");
                if (text_pos) |p| {
                    const txt = parseString(msg_json, p, &parsed.text_content);
                    parsed.text_len = txt.len;
                }
            },
            .video => {
                const dur_pos = findField(msg_json, "\"duration\":");
                if (dur_pos) |p| parsed.media_duration = @as(i32, @intCast(parseInt(msg_json, p)));
                const w_pos = findField(msg_json, "\"width\":");
                if (w_pos) |p| parsed.media_width = @as(i32, @intCast(parseInt(msg_json, p)));
                const h_pos = findField(msg_json, "\"height\":");
                if (h_pos) |p| parsed.media_height = @as(i32, @intCast(parseInt(msg_json, p)));
                const sz_pos = findField(msg_json, "\"size\":");
                if (sz_pos) |p| parsed.media_size = parseInt(msg_json, p);
            },
            .photo => {
                const w_pos = findField(msg_json, "\"width\":");
                if (w_pos) |p| parsed.media_width = @as(i32, @intCast(parseInt(msg_json, p)));
                const h_pos = findField(msg_json, "\"height\":");
                if (h_pos) |p| parsed.media_height = @as(i32, @intCast(parseInt(msg_json, p)));
                const sz_pos = findField(msg_json, "\"size\":");
                if (sz_pos) |p| parsed.media_size = parseInt(msg_json, p);
            },
            .document => {
                const fname_pos = findField(msg_json, "\"file_name\":\"");
                if (fname_pos) |p| {
                    const fname = parseString(msg_json, p, &parsed.file_name);
                    parsed.file_name_len = fname.len;
                }
                const sz_pos = findField(msg_json, "\"size\":");
                if (sz_pos) |p| parsed.media_size = parseInt(msg_json, p);
            },
            .audio => {
                const dur_pos = findField(msg_json, "\"duration\":");
                if (dur_pos) |p| parsed.media_duration = @as(i32, @intCast(parseInt(msg_json, p)));
                const sz_pos = findField(msg_json, "\"size\":");
                if (sz_pos) |p| parsed.media_size = parseInt(msg_json, p);
            },
            .sticker => {
                const emoji_pos = findField(msg_json, "\"emoji\":\"");
                if (emoji_pos) |p| {
                    const em = parseString(msg_json, p, &parsed.emoji);
                    parsed.emoji_len = em.len;
                }
            },
            .animation => {
                const dur_pos = findField(msg_json, "\"duration\":");
                if (dur_pos) |p| parsed.media_duration = @as(i32, @intCast(parseInt(msg_json, p)));
                const sz_pos = findField(msg_json, "\"size\":");
                if (sz_pos) |p| parsed.media_size = parseInt(msg_json, p);
            },
            .voice_note => {
                const dur_pos = findField(msg_json, "\"duration\":");
                if (dur_pos) |p| parsed.media_duration = @as(i32, @intCast(parseInt(msg_json, p)));
            },
            else => {},
        }

        return parsed;
    }

    fn formatMessagesText(messages: []const ParsedMessage) []const u8 {
        var pos: usize = 0;
        const total = messages.len;
        const prefix = "=== ";
        const suffix = " messages ===\n\n";
        var buf: [64]u8 = undefined;
        const header = std.fmt.bufPrintZ(&buf, "{s}{d}{s}", .{prefix, total, suffix}) catch "";
        @memcpy(text_buffer[pos..pos+header.len], header);
        pos += header.len;

        for (messages) |msg| {
            const ts_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[{d}] {d} ({d}): ", .{msg.date, msg.user_id, msg.chat_id}) catch break;
            pos += ts_slice.len;

            switch (msg.msg_type) {
                .text => {
                    const txt_slice = std.fmt.bufPrintZ(text_buffer[pos..], "{s}\n", .{msg.text_content[0..msg.text_len]}) catch break;
                    pos += txt_slice.len;
                },
                .video => {
                    const vid_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Video {}s {}x{}, {}]\n", .{msg.media_duration, msg.media_width, msg.media_height, msg.media_size}) catch break;
                    pos += vid_slice.len;
                },
                .photo => {
                    const ph_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Photo {}x{}, {}]\n", .{msg.media_width, msg.media_height, msg.media_size}) catch break;
                    pos += ph_slice.len;
                },
                .document => {
                    const doc_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Document: {s}, {}]\n", .{msg.file_name[0..msg.file_name_len], msg.media_size}) catch break;
                    pos += doc_slice.len;
                },
                .audio => {
                    const aud_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Audio {}s, {}]\n", .{msg.media_duration, msg.media_size}) catch break;
                    pos += aud_slice.len;
                },
                .sticker => {
                    const st_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Sticker {s}]\n", .{msg.emoji[0..msg.emoji_len]}) catch break;
                    pos += st_slice.len;
                },
                .animation => {
                    const anim_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Animation {}s, {}]\n", .{msg.media_duration, msg.media_size}) catch break;
                    pos += anim_slice.len;
                },
                .voice_note => {
                    const vn_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[VoiceNote {}s]\n", .{msg.media_duration}) catch break;
                    pos += vn_slice.len;
                },
                .location => {
                    const loc_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Location]\n", .{}) catch break;
                    pos += loc_slice.len;
                },
                .contact => {
                    const cnt_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Contact: {s}]\n", .{msg.text_content[0..msg.text_len]}) catch break;
                    pos += cnt_slice.len;
                },
                else => {
                    const unk_slice = std.fmt.bufPrintZ(text_buffer[pos..], "[Unknown]\n", .{}) catch break;
                    pos += unk_slice.len;
                },
            }

            if (pos > text_buffer.len - 500) break;
        }

        return text_buffer[0..pos];
    }

    fn countMessages(json: []const u8) usize {
        var count: usize = 0;
        var remaining = json;
        while (true) {
            const idx = std.mem.indexOf(u8, remaining, "{\"@type\":\"message\"") orelse break;
            remaining = remaining[idx + 18..];
            count += 1;
        }
        return count;
    }

    fn parseMessagesToArray(json: []const u8, messages: []ParsedMessage) usize {
        var count: usize = 0;
        var remaining = json;
        while (count < messages.len) {
            const msg_start = std.mem.indexOf(u8, remaining, "{\"@type\":\"message\"") orelse break;
            remaining = remaining[msg_start..];
            const msg_end = std.mem.indexOf(u8, remaining, "}}") orelse break;
            const msg_json = remaining[0..msg_end + 2];
            remaining = remaining[msg_end + 2..];
            messages[count] = parseMessageFromJson(msg_json);
            count += 1;
        }
        return count;
    }

    fn formatChatsText(json: []const u8) []const u8 {
        var pos: usize = 0;
        const total_pos = findField(json, "\"total_count\":");
        if (total_pos) |p| {
            const total = parseInt(json, p);
            const header_slice = std.fmt.bufPrintZ(text_buffer[pos..], "=== {d} chats ===\n\n", .{total}) catch return text_buffer[0..pos];
            pos += header_slice.len;
        }

        if (std.mem.indexOf(u8, json, "\"chat_ids\":") != null) {
            const start = (std.mem.indexOf(u8, json, "[") orelse return text_buffer[0..pos]) + 1;
            const end = std.mem.indexOf(u8, json, "]") orelse return text_buffer[0..pos];
            var remaining = json[start..end];
            var chat_idx: u32 = 0;
            var i: usize = 0;
            while (i < remaining.len and chat_idx < 20) : (i += 1) {
                while (i < remaining.len and (remaining[i] == ' ' or remaining[i] == ',')) : (i += 1) {}
                if (i >= remaining.len) break;
                var end_idx = i;
                while (end_idx < remaining.len and (remaining[end_idx] >= '0' and remaining[end_idx] <= '9' or remaining[end_idx] == '-')) : (end_idx += 1) {}
                if (end_idx > i) {
                    const id_str = remaining[i..end_idx];
                    chat_idx += 1;
                    const line_slice = std.fmt.bufPrintZ(text_buffer[pos..], "  [{d}] Chat ID: {s}\n", .{chat_idx, id_str}) catch break;
                    pos += line_slice.len;
                }
                i = end_idx;
            }
        }

        return text_buffer[0..pos];
    }

    fn formatErrorText(code: i64, msg: []const u8) []const u8 {
        return std.fmt.bufPrintZ(&text_buffer, "[ERROR] {d}: {s}\n", .{code, msg}) catch "[ERROR]\n";
    }

    pub fn formatResponse(_: *Engine, json: []const u8, fmt: Format) []const u8 {
        switch (fmt) {
            .text => {
                if (std.mem.indexOf(u8, json, "\"@type\":\"messages\"") != null) {
                    var messages: [20]ParsedMessage = undefined;
                    const actual = parseMessagesToArray(json, &messages);
                    return formatMessagesText(messages[0..actual]);
                } else if (std.mem.indexOf(u8, json, "\"@type\":\"chats\"") != null) {
                    return formatChatsText(json);
                } else if (std.mem.indexOf(u8, json, "\"@type\":\"error\"") != null) {
                    const code_pos = findField(json, "\"code\":");
                    const code = if (code_pos) |p| parseInt(json, p) else 0;
                    var msg_buf: [256]u8 = undefined;
                    const msg_pos = findField(json, "\"message\":\"");
                    const msg = if (msg_pos) |p| parseString(json, p, &msg_buf) else "";
                    return formatErrorText(code, msg);
                }
                return json;
            },
            .json => return json,
            .raw => return json,
        }
    }

    pub fn getDialogs(_: *Engine, limit: u32, _dialog_type: []const u8) []const u8 {
        _ = _dialog_type;
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChats\",\"offset_order\":9223372036854775807,\"offset_chat_id\":0,\"limit\":{}}}", .{limit}) catch return "";
    }

    pub fn getSavedMessages(self: *Engine, limit: u32) []const u8 {
        const chat_id = if (self.saved_messages_chat_id > 0) self.saved_messages_chat_id else 555000000;
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChatHistory\",\"chat_id\":{},\"limit\":{},\"from_message_id\":0,\"offset\":0,\"reverse_direction\":true}}", .{chat_id, limit}) catch return "";
    }

    pub fn getSavedDialogs(_: *Engine, limit: u32) []const u8 {
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getSavedDialogs\",\"limit\":{}}}", .{limit}) catch return "";
    }

    pub fn getMessages(_: *Engine, chat_id: i64, limit: u32, _from_id: ?i64) []const u8 {
        _ = _from_id;
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChatHistory\",\"chat_id\":{},\"limit\":{}}}", .{chat_id, limit}) catch return "";
    }

    pub fn sendMessage(_: *Engine, chat_id: i64, text: []const u8, _reply_to: ?i64) []const u8 {
        _ = _reply_to;
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"sendMessage\",\"chat_id\":{},\"input_message_content\":{{\"@type\":\"inputMessageText\",\"text\":{{\"@type\":\"formattedText\",\"text\":\"{s}\"}}}}}}", .{chat_id, text}) catch return "";
    }

    pub fn searchMessages(_: *Engine, query: []const u8, limit: u32, chat_id: i64, min_date: i64, max_date: i64) []const u8 {
        if (min_date > 0 and max_date > 0) {
            return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"searchChatMessages\",\"chat_id\":{},\"query\":\"{s}\",\"limit\":{},\"min_date\":{},\"max_date\":{}}}", .{chat_id, query, limit, min_date, max_date}) catch return "";
        } else if (min_date > 0) {
            return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"searchChatMessages\",\"chat_id\":{},\"query\":\"{s}\",\"limit\":{},\"min_date\":{}}}", .{chat_id, query, limit, min_date}) catch return "";
        } else if (max_date > 0) {
            return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"searchChatMessages\",\"chat_id\":{},\"query\":\"{s}\",\"limit\":{},\"max_date\":{}}}", .{chat_id, query, limit, max_date}) catch return "";
        }
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"searchChatMessages\",\"chat_id\":{},\"query\":\"{s}\",\"limit\":{}}}", .{chat_id, query, limit}) catch return "";
    }

    pub fn searchPublicChats(_: *Engine, query: []const u8) []const u8 {
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"searchPublicChats\",\"query\":\"{s}\"}}", .{query}) catch return "";
    }

    pub fn getChatInfo(_: *Engine, chat_id: i64) []const u8 {
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChat\",\"chat_id\":{}}}", .{chat_id}) catch return "";
    }

    pub fn getGroups(self: *Engine, limit: u32) []const u8 {
        return self.getDialogs(limit, "groups");
    }

    pub fn getChannels(self: *Engine, limit: u32) []const u8 {
        return self.getDialogs(limit, "channels");
    }

    pub fn getMe(_: *Engine) []const u8 {
        return "{\"@type\":\"getMe\"}";
    }

    pub fn getContacts(_: *Engine, limit: u32) []const u8 {
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getContacts\",\"limit\":{}}}", .{limit}) catch return "";
    }

    pub fn getGroupMessages(_: *Engine, chat_id: i64, limit: u32, from_id: ?i64) []const u8 {
        if (from_id) |fid| {
            return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChatHistory\",\"chat_id\":{},\"limit\":{},\"from_message_id\":{},\"offset\":0,\"reverse_direction\":true}}", .{chat_id, limit, fid}) catch return "";
        }
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChatHistory\",\"chat_id\":{},\"limit\":{},\"from_message_id\":9223372036854775807,\"offset\":0,\"reverse_direction\":true}}", .{chat_id, limit}) catch return "";
    }

    pub fn getChannelMessages(_: *Engine, chat_id: i64, limit: u32, from_id: ?i64) []const u8 {
        if (from_id) |fid| {
            return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChatHistory\",\"chat_id\":{},\"limit\":{},\"from_message_id\":{}}}", .{chat_id, limit, fid}) catch return "";
        }
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"getChatHistory\",\"chat_id\":{},\"limit\":{}}}", .{chat_id, limit}) catch return "";
    }

    pub fn getContactMessages(_: *Engine, user_id: i64, limit: u32, from_id: ?i64) []const u8 {
        _ = limit;
        _ = from_id;
        return std.fmt.bufPrintZ(&json_buffer, "{{\"@type\":\"createPrivateChat\",\"user_id\":{},\"force\":true}}", .{user_id}) catch return "";
    }
};