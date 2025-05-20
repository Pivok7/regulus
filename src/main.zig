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
    const allocator = std.heap.page_allocator;

    // init raylib
    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .window_resizable = true,
    });
    rl.initWindow(1000, 1000, "Raylib zig Example");
    defer rl.closeWindow();
    rl.setTargetFPS(120);

    // init clay
    try ui.init(allocator);
    defer ui.deinit();

    try flst.init(allocator);
    defer flst.deinit();

    while (!rl.windowShouldClose()) {
        try ui.render();
    }
}
