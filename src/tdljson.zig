const std = @import("std");

pub const TelegramClient = struct {
    client: *anyopaque,

    pub fn create() !*@This() {
        const cl = td_json_client_create();
        if (cl == null) {
            return error.ClientCreationFailed;
        }
        const result: *@This() = try std.heap.page_allocator.create(@This());
        result.* = @This(){ .client = cl.? };
        return result;
    }

    pub fn send(self: *@This(), request: []const u8) void {
        const req_z: [*:0]const u8 = @ptrCast(request.ptr);
        td_json_client_send(self.client, req_z);
    }

    pub fn receive(self: *@This(), timeout_secs: f64) ?[]const u8 {
        const result = td_json_client_receive(self.client, timeout_secs);
        if (result) |res| {
            var len: usize = 0;
            while (res[len] != 0) : (len += 1) {}
            return result.?[0..len];
        }
        return null;
    }

    pub fn execute(self: *@This(), request: []const u8) ?[]const u8 {
        const req_z: [*:0]const u8 = @ptrCast(request.ptr);
        const result = td_json_client_execute(self.client, req_z);
        if (result) |res| {
            var len: usize = 0;
            while (res[len] != 0) : (len += 1) {}
            return result.?[0..len];
        }
        return null;
    }

    pub fn destroy(self: *@This()) void {
        td_json_client_destroy(self.client);
        std.heap.page_allocator.destroy(self);
    }
};

extern fn td_json_client_create() callconv(.c) ?*anyopaque;
extern fn td_json_client_send(client: *anyopaque, request: [*:0]const u8) callconv(.c) void;
extern fn td_json_client_receive(client: *anyopaque, timeout: f64) callconv(.c) ?[*:0]const u8;
extern fn td_json_client_execute(client: *anyopaque, request: [*:0]const u8) callconv(.c) ?[*:0]const u8;
extern fn td_json_client_destroy(client: *anyopaque) callconv(.c) void;

extern fn td_set_log_file_path(_: [*:0]const u8) callconv(.c) i32;
extern fn td_set_log_max_file_size(_: u64) callconv(.c) void;
extern fn td_set_log_verbosity_level(_: i32) callconv(.c) void;

pub fn disableTDLibLogging() void {
    td_set_log_verbosity_level(0);
    td_set_log_max_file_size(0);
}