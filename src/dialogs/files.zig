const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const clay = @import("zclay");
const renderer = @import("../raylib_render_clay.zig");
const debug_mode = @import("../main.zig").debug_mode;
const flst = @import("../file_system.zig");
const ui = @import("../ui.zig");
const Allocator = std.mem.Allocator;

const max_files: usize = 2048;

pub const Modes = enum{
    select,
    save,
};

pub var context = struct{
    allocator: Allocator,
    mode: Modes,
    selected_file: std.ArrayList(u8),
    change_dir: ?[]const u8,
    input_text: std.ArrayList(u8),
    inputting: bool,
    finished: bool,
} {
    .allocator = undefined,
    .mode = undefined,
    .selected_file = undefined,
    .change_dir = null,
    .input_text = undefined,
    .inputting = false,
    .finished = false,
};

pub fn init(allocator: Allocator, mode: Modes) !void {
    context.allocator = allocator;
    context.mode = mode;
    context.selected_file = std.ArrayList(u8).init(allocator);

    context.input_text = std.ArrayList(u8).init(allocator);
    try context.input_text.appendSlice("filename");
    context.inputting = false;
}

pub fn deinit() void {
    defer context.allocator = undefined;
    context.mode = undefined;
    context.selected_file.deinit();
    context.change_dir = null;
    context.input_text.deinit();
    context.inputting = false;
} 

pub fn render() !?[]const u8 {
    if (context.change_dir != null) {
        if (try flst.isDir(context.change_dir.?)) {
            try flst.changeDir(context.change_dir.?);
            context.change_dir = null;
        } else {
            if (context.mode == .select) {
                context.finished = true;
            }
        }
    }

    if (context.finished) {
        if (context.mode == .select) {
            try context.selected_file.appendSlice(context.change_dir.?);
            return context.selected_file.items;
        } else {
            const cwd_text = try std.fs.cwd().realpathAlloc(context.allocator, ".");
            try context.selected_file.appendSlice(cwd_text);
            context.allocator.free(cwd_text);

            try context.selected_file.append('/');
            try context.selected_file.appendSlice(context.input_text.items);
            context.finished = false;

            return context.selected_file.items;
        }
    }

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
    var render_commands = try createLayout();

    if (context.mode == .save) {
        try inputText();
    }

    rl.beginDrawing();
    try renderer.clayRaylibRender(&render_commands, context.allocator);
    rl.endDrawing();

    return null;
}

fn inputText() !void {
    const key = rl.getKeyPressed();
    const key_char = rl.getCharPressed();
    
    if (context.inputting) {
        switch (key) {
            .null => {},
            .backspace => {
                _ = context.input_text.pop();
            },
            .enter => {
                context.finished = true;
            },
            else => {
                try context.input_text.append(@intCast(key_char));
            }
        }
    }
}

fn createLayout() !clay.ClayArray(clay.RenderCommand) {
    clay.beginLayout();
    clay.UI()(.{
        .id = .ID("OuterContainer"),
        .layout = .{
            .sizing = .grow,
            .direction = .top_to_bottom,
            .padding = .all(16),
            .child_gap = 16
        },
        .background_color = ui.white,
    })({
        clay.UI()(.{
            .id = .ID("FilePathBar"),
            .layout = .{
                .sizing = .{ .h = .fixed(50), .w = .grow },
                .child_alignment = .center,
                .child_gap = 16,
            },
            .background_color = ui.light_grey,
            .corner_radius = ui.global_corner_radius,
        })({
            clay.UI()(.{
                .id = .ID("Back"),
                .layout = .{
                    .sizing = .{ .h = .grow, .w = .fit },
                    .child_alignment = .center,
                    .padding = .{ .left = 16, .right = 16 },
                },
                .background_color = if (clay.hovered()) ui.red else ui.orange,
                .corner_radius = ui.global_corner_radius,
            })({
                clay.onHover(void, {}, struct {
                    pub fn callback(_: clay.ElementId, _: clay.PointerData, _: void) void {
                        if (rl.isMouseButtonPressed(.left)) {
                            context.change_dir = "..";
                        }
                    }
                }.callback);

                clay.text("Back", .{
                    .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                    .font_size = 24,
                    .color = .{ 61, 26, 5, 255 }
                });
            });

            clay.UI()(.{
                .layout = .{
                    .sizing = .grow,
                    .child_alignment = .{ .x = .left, .y = .center },
                },
                .scroll = .{
                    .vertical = true,
                    .horizontal = false
                },
                .background_color = ui.light_grey,
                .corner_radius = ui.global_corner_radius,
            })({
                var cwd_buf = std.mem.zeroes([std.fs.max_path_bytes:0]u8);
                const cwd_text = @as([:0]u8, @ptrCast(try std.fs.cwd().realpath(".", &cwd_buf)));

                clay.text(cwd_text, .{
                    .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                    .font_size = 24,
                    .color = .{ 61, 26, 5, 255 }
                });
            });
        });

        clay.UI()(.{
            .id = .ID("MainContent"),
            .layout = .{
                .sizing = .{ .h = .grow, .w = .grow },
                .direction = .top_to_bottom,
                .child_alignment = .center,
            },
            .background_color = ui.light_grey,
            .corner_radius = ui.global_corner_radius,
        })({
            clay.UI()(.{
                .id = .ID("DirectoryListContainer"),
                .layout = .{
                    .sizing = .grow,
                    .direction = .top_to_bottom,
                    .child_alignment = .{ .x = .center },
                    .padding = .all(16),
                    .child_gap = 16
                },
                .scroll = .{
                    .vertical = true,
                    .horizontal = false
                },
                .background_color = ui.light_grey,
                .corner_radius = ui.global_corner_radius,
            })({
                for (flst.fs_context.dir_list.items, 0..) |item, i| {
                    if (item.len == 0) break;
                    if (i >= max_files) {
                        std.log.warn("File limit of {d} exceeded", .{max_files});
                        break;
                    }

                    const hovered_base = clay.pointerOver(clay.getElementId("DirectoryListContainer"));

                    clay.UI()(.{
                        .layout = .{
                            .sizing = .{ .w = .grow, .h = .fixed(50) },
                            .child_alignment = .{ .y = .center },
                            .padding = .all(8),
                        },
                        .background_color = if (hovered_base and clay.hovered()) ui.red
                            else if (!try flst.isDir(item[0..item.len-1])) ui.white
                            else ui.orange,
                        .corner_radius = .all(8),
                    })({
                        if (hovered_base) {
                            clay.onHover([*c]const u8, item.ptr, struct {
                                pub fn callback(_: clay.ElementId, _: clay.PointerData, user_data: [*c]const u8) void {
                                    if (rl.isMouseButtonPressed(.left)) {
                                        context.change_dir = std.mem.span(user_data);
                                    }
                                }
                            }.callback);
                        }

                        clay.text(
                            item,
                            .{
                                .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                                .font_size = 24,
                                .color = .{ 61, 26, 5, 255 }
                            }
                        );
                    });
                }
            });

            if (context.mode == .save) {
                clay.UI()(.{
                    .id = .ID("TextInput"),
                    .layout = .{
                        .sizing = .{ .h = .fixed(80), .w = .grow },
                        .child_alignment = .center,
                        .child_gap = 16,
                        .padding = .all(16),
                    },
                    .background_color = ui.light_grey,
                    .corner_radius = ui.global_corner_radius,
                })({
                    clay.UI()(.{
                        .id = .ID("Save"),
                        .layout = .{
                            .sizing = .{ .h = .grow, .w = .fit },
                            .child_alignment = .center,
                            .child_gap = 16,
                            .padding = .{ .left = 16, .right = 16 },
                        },
                        .background_color = if (clay.hovered()) ui.red else ui.orange,
                        .corner_radius = ui.global_corner_radius,
                    })({
                        clay.text("Save", .{
                            .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                            .font_size = 24,
                            .color = .{ 61, 26, 5, 255 }
                        });

                        clay.onHover(void, {}, struct {
                            pub fn callback(_: clay.ElementId, _: clay.PointerData, _: void) void {
                                if (rl.isMouseButtonPressed(.left)) {
                                    context.finished = true;
                                }
                            }
                        }.callback);
                    });

                    clay.UI()(.{
                        .id = .ID("TextField"),
                        .layout = .{
                            .sizing = .{ .h = .grow, .w = .grow },
                            .child_alignment = .{ .x = .left, .y = .center },
                            .child_gap = 16,
                            .padding = .{ .left = 16, .right = 16 },
                        },
                        .background_color = if (clay.hovered() and !context.inputting) ui.red else ui.orange,
                        .corner_radius = ui.global_corner_radius,
                    })({
                        if (rl.isMouseButtonPressed(.left) and !clay.hovered()) {
                            context.inputting = false;
                        }

                        clay.text(context.input_text.items, .{
                            .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                            .font_size = 24,
                            .color = .{ 61, 26, 5, 255 }
                        });

                        clay.onHover(void, {}, struct {
                            pub fn callback(_: clay.ElementId, _: clay.PointerData, _: void) void {
                                if (rl.isMouseButtonPressed(.left)) {
                                    context.inputting = true;
                                }
                            }
                        }.callback);
                    });
                });
            }
        });
    });
    return clay.endLayout();
}

