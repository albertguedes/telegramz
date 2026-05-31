const std = @import("std");
const tdljson = @import("tdljson.zig");
const config = @import("config.zig");

pub const AuthState = enum {
    unknown,
    wait_phone_number,
    wait_code,
    wait_password,
    ready,
    closed,
};

pub const AuthHandler = struct {
    client: *tdljson.TelegramClient,
    state: AuthState = .unknown,
    config: *const config.Config,
    
    pub fn init(client: *tdljson.TelegramClient, cfg: *const config.Config) !*AuthHandler {
        const handler = std.heap.page_allocator.create(AuthHandler) catch return error.OutOfMemory;
        handler.* = AuthHandler{
            .client = client,
            .state = .unknown,
            .config = cfg,
        };
        return handler;
    }
    
    pub fn checkAuthorizationState(self: *AuthHandler, json_response: []const u8) AuthState {
        if (std.mem.indexOf(u8, json_response, "\"authorizationStateWaitPhoneNumber\"")) |_| {
            self.state = .wait_phone_number;
        } else if (std.mem.indexOf(u8, json_response, "\"authorizationStateWaitCode\"")) |_| {
            self.state = .wait_code;
        } else if (std.mem.indexOf(u8, json_response, "\"authorizationStateWaitPassword\"")) |_| {
            self.state = .wait_password;
        } else if (std.mem.indexOf(u8, json_response, "\"authorizationStateReady\"")) |_| {
            self.state = .ready;
        } else if (std.mem.indexOf(u8, json_response, "\"authorizationStateClosed\"")) |_| {
            self.state = .closed;
        }
        return self.state;
    }

    pub fn getState(self: *AuthHandler) AuthState {
        return self.state;
    }
};

pub fn waitForAuthState(client: *tdljson.TelegramClient, target_state: AuthState, timeout_secs: f64) !AuthState {
    const start = std.time.timestamp();
    var last_state: AuthState = .unknown;
    
    while (@as(i64, std.time.timestamp()) - start < @as(i64, @intFromFloat(timeout_secs))) {
        if (client.receive(0.5)) |resp| {
            if (std.mem.indexOf(u8, resp, "\"@type\":")) |_| {
                if (std.mem.indexOf(u8, resp, "authorizationState")) |_| {
                    if (std.mem.indexOf(u8, resp, "authorizationStateWaitPhoneNumber")) |_| {
                        last_state = .wait_phone_number;
                        if (last_state == target_state) return last_state;
                    } else if (std.mem.indexOf(u8, resp, "authorizationStateWaitCode")) |_| {
                        last_state = .wait_code;
                        if (last_state == target_state) return last_state;
                    } else if (std.mem.indexOf(u8, resp, "authorizationStateWaitPassword")) |_| {
                        last_state = .wait_password;
                        if (last_state == target_state) return last_state;
                    } else if (std.mem.indexOf(u8, resp, "authorizationStateReady")) |_| {
                        last_state = .ready;
                        return last_state;
                    } else if (std.mem.indexOf(u8, resp, "authorizationStateClosed")) |_| {
                        last_state = .closed;
                        return last_state;
                    }
                }
            }
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    
    return last_state;
}