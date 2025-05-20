const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const ui = @import("ui.zig");
const flst = @import("file_system.zig");

pub const debug_mode = switch (builtin.mode) {
    .Debug => true,
    else => false,
};

pub fn main() !void {
    var dba = std.heap.DebugAllocator(.{}){};
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    // init raylib
    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .window_resizable = true,
    });
    rl.setTraceLogLevel(.none);
    rl.initWindow(1000, 1000, "Raylib zig Example");
    defer rl.closeWindow();
    rl.setTargetFPS(120);

    // init clay
    try ui.init(allocator);
    defer ui.deinit();

    try flst.init(allocator);
    defer flst.deinit();

    while (!rl.windowShouldClose()) {
        const ret = try ui.render();
        if (ret != null) {
            std.debug.print("{s}", .{ret.?});
            std.process.exit(0);
        }
    }
}
