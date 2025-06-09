const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const clay = @import("zclay");
const renderer = @import("../raylib_render_clay.zig");
const flst = @import("../file_system.zig");
const ui = @import("../ui.zig");
const Allocator = std.mem.Allocator;

const max_files_per_page: usize = 64;
pub var backspace_held_time: f32 = 0.0;
pub var mouse_held_time: f32 = 0.0;

pub const Modes = enum {
    select,
    save,
};

pub var context = struct {
    allocator: Allocator,
    mode: Modes,
    current_page: usize,
    max_page: usize,
    selected_file: std.ArrayList(u8),
    change_dir: ?[]const u8,
    cwd_str: ?[]const u8,
    input_text: std.ArrayList(u8),
    inputting: bool,
    finished: bool,
} {
    .allocator = undefined,
    .mode = undefined,
    .current_page = 1,
    .max_page = 1,
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
    context.current_page = 1;
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

            context.current_page = 1;
            context.max_page = @divFloor(flst.fs_context.dir_list.items.len - 1, max_files_per_page) + 1;

            clay.updateScrollContainers(
                true,
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
            if (builtin.target.os.tag == .windows) {
                try context.selected_file.append('\\');
            } else {
                try context.selected_file.append('/');
            }
            try context.selected_file.appendSlice(context.change_dir.?);
            return context.selected_file.items;
        } else {
            const cwd_text = try std.fs.cwd().realpathAlloc(context.allocator, ".");
            try context.selected_file.appendSlice(cwd_text);
            context.allocator.free(cwd_text);

            if (builtin.target.os.tag == .windows) {
                try context.selected_file.append('\\');
            } else {
                try context.selected_file.append('/');
            }
            try context.selected_file.appendSlice(context.input_text.items);
            context.finished = false;

            return context.selected_file.items;
        }
    }

    if (context.mode == .save) {
        try inputText();
    }

    var page_num_buf = std.mem.zeroes([32]u8);
    const page_num_text = std.fmt.bufPrint(
        &page_num_buf, "Page: {d} / {d}",
        .{context.current_page, context.max_page}
    ) catch unreachable;

    const render_commands = try createLayout(page_num_text);

    rl.beginDrawing();
    try renderer.clayRaylibRender(render_commands, context.allocator);
    rl.endDrawing();

    return null;
}

fn inputText() !void {
    const key = rl.getKeyPressed();
    const key_char = rl.getCharPressed();

    if (context.inputting) {
        if (buttonLongPress(&backspace_held_time, .backspace) or key == .backspace) {
            //We erase bytes in loop until we hit unicode starting byte
            while (true) {
                const last_byte = context.input_text.pop();

                if (last_byte) |byte| {
                    _ = std.unicode.utf8ByteSequenceLength(byte) catch continue;
                    return;
                } else {
                    return;
                }
            }
        }

        switch (key) {
            .enter => {
                context.finished = true;
            },
            else => {
                if (key_char != 0) {
                    var utf8: [4]u8 = undefined;
                    const out_bytes = try std.unicode.utf8Encode(@intCast(key_char), &utf8);

                    try context.input_text.appendSlice(utf8[0..out_bytes]);
                }
            }
        }
    }
}

fn createLayout(page_num_text: []const u8) ![]clay.RenderCommand {
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

        const lower_bound = (context.current_page - 1) * max_files_per_page;
        const upper_bound = @min(flst.fs_context.dir_list.items.len, context.current_page * max_files_per_page);

        if (context.max_page > 1) {
            clayRenderPageBar(upper_bound, page_num_text);
        }

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
            const hovered_base = clay.pointerOver(clay.getElementId("DirectoryListContainer"));

            // A bit of magic numbers becuase setting sizing to grow caused some problems
            var height = @as(f32, @floatFromInt(rl.getScreenHeight())) - 132.0;

            if (context.mode == .save) height -= (50.0 + 16.0);
            if (context.max_page > 1) height -= (50.0 + 16.0);

            height = @max(height, 50.0);

            clay.UI()(.{
                .id = .ID("DirectoryListContainer"),
                .layout = .{
                    .sizing = .{ .h = .fixed(height), .w = .grow },
                    .direction = .top_to_bottom,
                    .child_alignment = .{ .x = .center },
                    .padding = .all(16),
                    .child_gap = 16
                },
                .clip = .{ .vertical = true, .child_offset = clay.getScrollOffset() },
                .background_color = ui.light_grey,
                .corner_radius = ui.global_corner_radius,
            })({
                for (lower_bound..upper_bound) |i| {
                    const item = flst.fs_context.dir_list.items[i];
                    if (item.len == 0) break;

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
    return clay.endLayout();
}

pub fn clayRenderPageBar(upper_bound: usize, page_num_text: []const u8) void {
    clay.UI()(.{
        .layout = .{
            .sizing = .{ .w = .grow, .h = .fixed(50) },
            .child_alignment = .{ .y = .center },
            .direction = .left_to_right,
            .child_gap = 8,
        },
        .background_color = ui.light_grey,
        .corner_radius = .all(8),
    })({
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .grow },
                .child_alignment = .center,
            },
            .background_color = ui.light_grey,
            .corner_radius = .all(8),
        })({

            clay.text(page_num_text, .{
                .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                .font_size = 24,
                .color = .{ 61, 26, 5, 255 }
            });
        });

        if (context.current_page > 1) {
            clayRenderPageButtonLeft();
        } else {
            clay.UI()(.{
                .layout = .{
                    .sizing = .{ .w = .fixed(70), .h = .grow },
                },
                .background_color = ui.orange,
                .corner_radius = .all(8),
            })({});
        }

        if (upper_bound < flst.fs_context.dir_list.items.len) {
            clayRenderPageButtonRight();
        } else {
            clay.UI()(.{
                .layout = .{
                    .sizing = .{ .w = .fixed(70), .h = .grow },
                },
                .background_color = ui.orange,
                .corner_radius = .all(8),
            })({});
        }
    });
}

pub fn clayRenderPageButtonRight() void {
    clay.UI()(.{
        .layout = .{
            .sizing = .{ .w = .fixed(70), .h = .grow },
            .child_alignment = .center,
            .padding = .all(8),
        },
        .background_color = if (clay.hovered()) ui.red
            else ui.orange,
        .corner_radius = .all(8),
    })({
        clay.onHover(void, {}, struct {
            pub fn callback(_: clay.ElementId, _: clay.PointerData, _: void) void {
                if (mouseLongPress(&mouse_held_time, .left) or rl.isMouseButtonPressed(.left)) {
                    if (context.current_page < context.max_page) {
                        updatePage(context.current_page + 1);
                    }
                }
            }
        }.callback);

        clay.text(
            "--->",
            .{
                .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                .font_size = 24,
                .color = .{ 61, 26, 5, 255 }
            }
        );
    });
}

pub fn clayRenderPageButtonLeft() void {
    clay.UI()(.{
        .layout = .{
            .sizing = .{ .w = .fixed(70), .h = .grow },
            .child_alignment = .center,
            .padding = .all(8),
        },
        .background_color = if (clay.hovered()) ui.red
            else ui.orange,
        .corner_radius = .all(8),
    })({
        clay.onHover(void, {}, struct {
            pub fn callback(_: clay.ElementId, _: clay.PointerData, _: void) void {
                if (mouseLongPress(&mouse_held_time, .left) or rl.isMouseButtonPressed(.left)) {
                    if (context.current_page > 1) {
                        updatePage(context.current_page - 1);
                    }
                }
            }
        }.callback);

        clay.text(
            "<---",
            .{
                .font_id = ui.FONT_ID_QUICKSAND_SEMIBOLD_24,
                .font_size = 24,
                .color = .{ 61, 26, 5, 255 }
            }
        );
    });
}

pub fn updatePage(val: usize) void {
    if (val < 1) {
        std.log.warn("Invalid page set {d}", .{val});
        context.current_page = 1;
    } else if (val > context.max_page) {
        std.log.warn("Invalid page set {d}", .{val});
        context.current_page = context.max_page;
    } else {
        context.current_page = val;
    }

    clay.updateScrollContainers(
        true,
        .{ .x = 0, .y = 100000 },
        100.0,
    );
}

fn buttonLongPress(held_time: *f32, key: rl.KeyboardKey) bool {
    const activation_time: f32 = 0.3;
    const press_frequency: f32 = 0.03;

    if (rl.isKeyDown(key)) {
        held_time.* += rl.getFrameTime();
    } else {
        held_time.* = 0.0;
    }
    if (held_time.* > activation_time) {
        if (held_time.* > activation_time + press_frequency) {
            held_time.* = activation_time;
            return true;
        }
    }
    return false;
}

fn mouseLongPress(held_time: *f32, key: rl.MouseButton) bool {
    const activation_time: f32 = 0.2;
    const press_frequency: f32 = 0.05;

    if (rl.isMouseButtonDown(key)) {
        held_time.* += rl.getFrameTime();
    } else {
        held_time.* = 0.0;
    }
    if (held_time.* > activation_time) {
        if (held_time.* > activation_time + press_frequency) {
            held_time.* = activation_time;
            return true;
        }
    }
    return false;
}
