const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const clay = @import("zclay");
const renderer = @import("../raylib_render_clay.zig");
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
    cwd_str: ?[]const u8,
    input_text: std.ArrayList(u8),
    inputting: bool,
    finished: bool,
} {
    .allocator = undefined,
    .mode = undefined,
    .selected_file = undefined,
    .change_dir = null,
    .cwd_str = null,
    .input_text = undefined,
    .inputting = false,
    .finished = false,
};

pub fn init(allocator: Allocator, mode: Modes) !void {
    context.allocator = allocator;
    context.mode = mode;
    context.selected_file = std.ArrayList(u8).init(allocator);
    context.cwd_str = try std.fs.cwd().realpathAlloc(context.allocator, ".");

    context.input_text = std.ArrayList(u8).init(allocator);
    try context.input_text.appendSlice("filename");
    context.inputting = false;
}

pub fn deinit() void {
    defer context.allocator = undefined;
    context.mode = undefined;
    context.selected_file.deinit();
    context.change_dir = null;
    if (context.cwd_str != null) context.allocator.free(context.cwd_str.?);
    context.input_text.deinit();
    context.inputting = false;
} 

pub fn render() !?[]const u8 {
    if (context.change_dir != null) {
        if (try flst.isDir(context.change_dir.?)) {
            try flst.changeDir(context.change_dir.?);
            context.change_dir = null;
            
            if (context.cwd_str != null) {
                context.allocator.free(context.cwd_str.?);
            }
            context.cwd_str = try std.fs.cwd().realpathAlloc(context.allocator, ".");

            // Go to top
            clay.updateScrollContainers(
                false,
                .{ .x = 0, .y = 100000 },
                100.0,
            );

        } else {
            if (context.mode == .select) {
                context.finished = true;
            }
        }
    }

    if (context.finished) {
        if (context.mode == .select) {
            try context.selected_file.appendSlice(context.cwd_str.?);
            try context.selected_file.append('/');
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
            .backspace => {
                _ = context.input_text.pop();
            },
            .enter => {
                context.finished = true;
            },
            else => {
                if (key_char != 0 and key_char < 128) {
                    try context.input_text.append(@intCast(key_char));
                }
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
                clay.text(context.cwd_str orelse "Null", .{
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
                    // A bit of magic numbers becuase setting sizing to grow caused some problems
                    .sizing = .{ 
                        .h = if (context.mode == .select) .fixed(@as(f32, @floatFromInt(rl.getScreenHeight())) - 128.0)
                            else .fixed(@as(f32, @floatFromInt(rl.getScreenHeight())) - 178.0),
                        .w = .grow
                    },
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
                const hovered_base = clay.pointerOver(clay.getElementId("DirectoryListContainer"));

                for (flst.fs_context.dir_list.items, 0..) |item, i| {
                    if (item.len == 0) break;
                    if (i >= max_files) {
                        std.log.warn("File limit of {d} exceeded", .{max_files});
                        break;
                    }

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
                        clay.onHover([*c]const u8, item.ptr, struct {
                            pub fn callback(_: clay.ElementId, _: clay.PointerData, user_data: [*c]const u8) void {
                                if (rl.isMouseButtonPressed(.left)) {
                                    if (clay.pointerOver(clay.getElementId("DirectoryListContainer"))) {
                                        context.change_dir = std.mem.span(user_data);
                                    }
                                }
                            }
                        }.callback);

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

