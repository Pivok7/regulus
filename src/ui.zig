const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const clay = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const debug_mode = @import("main.zig").debug_mode;
const flst = @import("file_system.zig");
const Allocator = std.mem.Allocator;

const light_grey: clay.Color = .{ 224, 215, 210, 255 };
const red: clay.Color = .{ 168, 66, 28, 255 };
const orange: clay.Color = .{ 225, 138, 50, 255 };
const white: clay.Color = .{ 250, 250, 255, 255 };

const FONT_ID_QUICKSAND_SEMIBOLD_24 = 0;

const global_corner_radius = clay.CornerRadius.all(8);

var clay_context = struct{
    allocator: Allocator,
    memory: []u8,
    debug_mode_on: bool,
    change_dir: ?[]const u8,
} {
    .allocator = undefined,
    .memory = undefined,
    .debug_mode_on = false,
    .change_dir = null,
};

pub fn init(allocator: std.mem.Allocator) !void {
    // init clay
    const min_memory_size: u32 = clay.minMemorySize();
    clay_context.allocator = allocator;
    clay_context.memory = try clay_context.allocator.alloc(u8, min_memory_size);
    clay_context.debug_mode_on = false;
    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(clay_context.memory);
    _ = clay.initialize(arena, .{ .h = 1000, .w = 1000 }, .{});
    clay.setMeasureTextFunction(void, {}, renderer.measureText);

    // load assets
    try loadFont(@embedFile("./resources/Quicksand-Semibold.ttf"), FONT_ID_QUICKSAND_SEMIBOLD_24, 24);
}

pub fn deinit() void {
    defer clay_context.allocator = undefined;
    clay_context.allocator.free(clay_context.memory);
    clay_context.debug_mode_on = false;
}

pub fn render() !?[]const u8 {
    if (rl.isKeyPressed(.d) and debug_mode) {
        clay_context.debug_mode_on = !clay_context.debug_mode_on;
        clay.setDebugModeEnabled(clay_context.debug_mode_on);
    }

    const mouse_pos = rl.getMousePosition();
    clay.setPointerState(.{
        .x = mouse_pos.x,
        .y = mouse_pos.y,
    }, rl.isMouseButtonDown(.left));

    if (clay_context.change_dir != null) {
        if (try flst.isDir(clay_context.change_dir.?)) {
            try flst.changeDir(clay_context.change_dir.?);
        } else {
            return clay_context.change_dir.?;
        }
        clay_context.change_dir = null;
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

    rl.beginDrawing();
    try renderer.clayRaylibRender(&render_commands, clay_context.allocator);
    rl.endDrawing();

    return null;
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
        .background_color = white,
    })({
        clay.UI()(.{
            .id = .ID("FilePathBar"),
            .layout = .{
                .sizing = .{ .h = .fixed(50), .w = .grow },
                .child_alignment = .center,
                .child_gap = 16,
            },
            .background_color = light_grey,
            .corner_radius = global_corner_radius,
        })({
            clay.UI()(.{
                .id = .ID("Back"),
                .layout = .{
                    .sizing = .{ .h = .fixed(50), .w = .fixed(100) },
                    .child_alignment = .center
                },
                .background_color = if (clay.hovered()) red else orange,
                .corner_radius = global_corner_radius,
            })({
                clay.onHover(void, {}, struct {
                    pub fn callback(_: clay.ElementId, _: clay.PointerData, _: void) void {
                        if (rl.isMouseButtonPressed(.left)) {
                            clay_context.change_dir = "..";
                        }
                    }
                }.callback);

                clay.text("Back", .{
                    .font_id = FONT_ID_QUICKSAND_SEMIBOLD_24,
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
                .background_color = light_grey,
                .corner_radius = global_corner_radius,
            })({
                var cwd_buf = std.mem.zeroes([std.fs.max_path_bytes:0]u8);
                const cwd_text = @as([:0]u8, @ptrCast(try std.fs.cwd().realpath(".", &cwd_buf)));

                clay.text(cwd_text, .{
                    .font_id = FONT_ID_QUICKSAND_SEMIBOLD_24,
                    .font_size = 24,
                    .color = .{ 61, 26, 5, 255 }
                });
            });
        });

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
            .background_color = light_grey,
            .corner_radius = global_corner_radius,
        })({
            for (flst.fs_context.dir_list.items) |item| {
                if (item.len == 0) break;

                clay.UI()(.{
                    .layout = .{
                        .sizing = .{ .w = .grow, .h = .fixed(50) },
                        .child_alignment = .{ .y = .center },
                        .padding = .all(8),
                    },
                    .background_color = if (clay.hovered()) red
                        else if (!try flst.isDir(item[0..item.len-1])) white
                        else orange,
                    .corner_radius = .all(8),
                })({
                    clay.onHover([*c]const u8, item.ptr, struct {
                        pub fn callback(_: clay.ElementId, _: clay.PointerData, user_data: [*c]const u8) void {
                            if (rl.isMouseButtonPressed(.left)) {
                                clay_context.change_dir = std.mem.span(user_data);
                            }
                        }
                    }.callback);

                    clay.text(
                        item,
                        .{
                            .font_id = FONT_ID_QUICKSAND_SEMIBOLD_24,
                            .font_size = 24,
                            .color = .{ 61, 26, 5, 255 }
                        }
                    );
                });
            }
        });
    });
    return clay.endLayout();
}

fn loadFont(file_data: ?[]const u8, font_id: u16, font_size: i32) !void {
    renderer.raylib_fonts[font_id] = try rl.loadFontFromMemory(".ttf", file_data, font_size * 2, null);
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

fn loadImage(comptime path: [:0]const u8) !rl.Texture2D {
    const texture = try rl.loadTextureFromImage(try rl.loadImageFromMemory(@ptrCast(std.fs.path.extension(path)), @embedFile(path)));
    rl.setTextureFilter(texture, .bilinear);
    return texture;
}

