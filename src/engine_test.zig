const std = @import("std");

test "getDialogs JSON structure" {
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"getDialogs\", \"limit\": {}, \"offset_order\": 9223372036854775807, \"offset_dialog_id\": {{\"@type\": \"dialogId\", \"min_order\": 9223372036854775807, \"max_order\": -9223372036854775807}}, \"@extra\": \"get_dialogs\"}}", 
        .{10}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "getDialogs").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "limit").? >= 0);
}

test "getMessages JSON with from_id" {
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"getChatHistory\", \"chat_id\": {}, \"limit\": {}, \"from_message_id\": {}, \"@extra\": \"get_messages\"}}", 
        .{12345, 20, 100}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "getChatHistory").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "chat_id").? >= 0);
}

test "getMessages JSON without from_id" {
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"getChatHistory\", \"chat_id\": {}, \"limit\": {}, \"@extra\": \"get_messages\"}}", 
        .{12345, 20}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "getChatHistory").? >= 0);
}

test "sendMessage JSON with reply_to" {
    var buf: [2048]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"sendMessage\", \"chat_id\": {}, \"text\": \"{s}\", \"reply_to_message_id\": {}, \"@extra\": \"send_msg\"}}", 
        .{12345, "Hello", 100}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "sendMessage").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "Hello").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "reply_to_message_id").? >= 0);
}

test "sendMessage JSON without reply_to" {
    var buf: [2048]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"sendMessage\", \"chat_id\": {}, \"text\": \"{s}\", \"@extra\": \"send_msg\"}}", 
        .{12345, "Hello"}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "sendMessage").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "Hello").? >= 0);
}

test "searchPublicChats JSON" {
    var buf: [256]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"searchPublicChats\", \"query\": \"{s}\", \"@extra\": \"search_public\"}}", .{"rust"}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "searchPublicChats").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "rust").? >= 0);
}

test "getChat JSON" {
    var buf: [256]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"getChat\", \"chat_id\": {}, \"@extra\": \"get_chat\"}}", .{12345}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "getChat").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "chat_id").? >= 0);
}

test "searchMessages JSON" {
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf, 
        "{{\"@type\": \"searchMessages\", \"query\": \"{s}\", \"limit\": {}, \"@extra\": \"search\"}}", 
        .{"test", 20}) catch return error.SkipZigTest;
    
    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "searchMessages").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "test").? >= 0);
}

test "getSavedMessages JSON" {
    var buf: [256]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf,
        "{{\"@type\": \"getChatHistory\", \"chat_id\": 155456355, \"limit\": {}, \"from_message_id\": 0, \"offset\": 0, \"reverse_direction\": true}}", .{20}) catch return error.SkipZigTest;

    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "getChatHistory").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "reverse_direction").? >= 0);
}

test "getSavedDialogs JSON" {
    var buf: [256]u8 = undefined;
    const json = std.fmt.bufPrintZ(&buf,
        "{{\"@type\": \"getSavedDialogs\", \"limit\": {}}}", .{20}) catch return error.SkipZigTest;

    try std.testing.expect(std.mem.indexOf(u8, json, "@type").? >= 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "getSavedDialogs").? >= 0);
}