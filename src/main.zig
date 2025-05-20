const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const ui = @import("ui.zig");
const flst = @import("file_system.zig");

pub const debug_mode = switch (builtin.mode) {
    .Debug => true,
    else => false,
};

const Flags = enum {
    nothing,
    file_dialog_select,
    file_dialog_save,
};

fn printHelp() void {
    std.debug.print(
        \\Options:
        \\  --file-dialog-select
        \\  --file-dialog-save
   , .{});
}

pub fn main() !void {
    var dba = std.heap.DebugAllocator(.{}){};
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    // We want to keep args in memory to use them later in program
    const args = try std.process.argsAlloc(allocator);
    errdefer std.process.argsFree(allocator, args);
    defer std.process.argsFree(allocator, args);

    var current_flag = Flags.nothing;

    if (args.len == 1) {
        printHelp();
        std.process.exit(0);
    }

    for (args) |arg| {
        if (std.mem.eql(u8, arg, args[0])) continue;

        if (std.mem.eql(u8, arg, "--file-dialog-select")) {
            current_flag = .file_dialog_select;
            continue;
        } else if (std.mem.eql(u8, arg, "--file-dialog-save")) {
            current_flag = .file_dialog_save;
            continue;
        } else {
            std.log.err("Invalid argument {s}", .{arg});
            std.log.err("Check --help", .{});
            std.process.exit(1);
        }
    }

    // init raylib
    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .window_resizable = true,
        .vsync_hint = true,
    });
    rl.setTraceLogLevel(.none);
    rl.initWindow(1000, 800, "Raylib zig Example");
    defer rl.closeWindow();

    // init clay
    try ui.init(allocator, switch(current_flag) {
        .file_dialog_select => .file_dialog_select,
        .file_dialog_save => .file_dialog_save,
        else => unreachable,
    });
    defer ui.deinit();

    try flst.init(allocator);
    defer flst.deinit();

    while (!rl.windowShouldClose()) {
        const res = try ui.render();
        if (res != null) {
            std.debug.print("{s}", .{res.?});
            std.process.exit(0);
        }
    }
}
