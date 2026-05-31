const std = @import("std");
const commands = @import("commands.zig");

test "commands.ok creates success result" {
    const result = commands.ok("test data");
    try std.testing.expect(result.ok == true);
    try std.testing.expect(result.code == 200);
    try std.testing.expect(result.data != null);
}

test "commands.errorResult creates error result" {
    const result = commands.errorResult("test error", 404);
    try std.testing.expect(result.ok == false);
    try std.testing.expect(result.code == 404);
    try std.testing.expect(result.err_msg != null);
}

test "commands.makeError creates error result" {
    const result = commands.makeError("error msg", 500);
    try std.testing.expect(result.ok == false);
    try std.testing.expect(result.code == 500);
}

test "commands.toJson formats success" {
    const result = commands.ok("data");
    const json = commands.toJson(result);
    try std.testing.expect(std.mem.indexOf(u8, json, "ok").? >= 0);
}

test "commands.toJson formats error" {
    const result = commands.errorResult("fail", 400);
    const json = commands.toJson(result);
    try std.testing.expect(std.mem.indexOf(u8, json, "ok").? >= 0);
}