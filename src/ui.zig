const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const clay = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const debug_mode = @import("main.zig").debug_mode;
const Allocator = std.mem.Allocator;

const dial_files = @import("dialogs/files.zig");

pub const light_grey: clay.Color = .{ 224, 215, 210, 255 };
pub const red: clay.Color = .{ 168, 66, 28, 255 };
pub const orange: clay.Color = .{ 225, 138, 50, 255 };
pub const white: clay.Color = .{ 250, 250, 255, 255 };

pub const FONT_ID_QUICKSAND_SEMIBOLD_24 = 0;

pub const global_corner_radius = clay.CornerRadius.all(8);

pub const Modes = enum {
    file_dialog_select,
    file_dialog_save,
};

pub var context = struct{
    allocator: Allocator,
    memory: []u8,
    debug_mode_on: bool,
    mode: Modes,
} {
    .allocator = undefined,
    .memory = undefined,
    .debug_mode_on = false,
    .mode = .file_dialog_select,
};

pub fn init(allocator: std.mem.Allocator, mode: Modes) !void {
    // init clay
    const min_memory_size: u32 = clay.minMemorySize();
    
    context.allocator = allocator;
    context.memory = try context.allocator.alloc(u8, min_memory_size);
    context.debug_mode_on = debug_mode;
    context.mode = mode;

    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(context.memory);
    _ = clay.initialize(arena, .{ .h = 1000, .w = 1000 }, .{});
    clay.setMeasureTextFunction(void, {}, renderer.measureText);

    // load assets
    try loadFont(allocator, @embedFile("./resources/Quicksand-Semibold.ttf"), FONT_ID_QUICKSAND_SEMIBOLD_24, 24);

    switch (context.mode) {
        .file_dialog_select => try dial_files.init(allocator, .select),
        .file_dialog_save => try dial_files.init(allocator, .save),
    }
}

pub fn deinit() void {
    dial_files.deinit();

    defer context.allocator = undefined;
    context.allocator.free(context.memory);
    context.debug_mode_on = false;
}

pub fn render() !?[]const u8 {
    if (rl.isKeyPressed(.d) and debug_mode) {
        context.debug_mode_on = !context.debug_mode_on;
        clay.setDebugModeEnabled(context.debug_mode_on);
    }

    const mouse_pos = rl.getMousePosition();
    clay.setPointerState(.{
        .x = mouse_pos.x,
        .y = mouse_pos.y,
    }, rl.isMouseButtonDown(.left));

    const scroll_delta = rl.getMouseWheelMoveV().multiply(.{ .x = 6, .y = 6 });
    clay.updateScrollContainers(
        false,
        .{ .x = scroll_delta.x, .y = scroll_delta.y },
        rl.getFrameTime(),
    );

    clay.setLayoutDimensions(.{
        .w = @floatFromInt(rl.getScreenWidth()),
        .h = @floatFromInt(rl.getScreenHeight()),
    });

    const res = try dial_files.render();
    if (res != null) {
        return res.?;
    }

    return null;
}

fn loadFont(allocator: Allocator, file_data: ?[]const u8, font_id: u16, font_size: i32) !void {
    var all_letters = std.ArrayList(u8).init(allocator);
    defer all_letters.deinit();

    //INFO: Just guessing the font range
    for (32..2048) |i| {
        var utf8: [4]u8 = undefined;
        const out_bytes = try std.unicode.utf8Encode(@intCast(i), &utf8);
        try all_letters.appendSlice(utf8[0..out_bytes]);
    }
    try all_letters.append(0);

    const codepoints = try rl.loadCodepoints(@ptrCast(all_letters.items));
    defer rl.unloadCodepoints(codepoints);

    renderer.raylib_fonts[font_id] = try rl.loadFontFromMemory(".ttf", file_data, font_size * 2, codepoints);
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

fn loadImage(comptime path: [:0]const u8) !rl.Texture2D {
    const texture = try rl.loadTextureFromImage(try rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}

