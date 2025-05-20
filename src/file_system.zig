const std = @import("std");
const Allocator = std.mem.Allocator;

pub var fs_context = struct{
    allocator: Allocator,
    dir_list: std.ArrayList(u8),
    original_cwd: std.fs.Dir,
} {
    .allocator = undefined,
    .dir_list = undefined,
    .original_cwd = undefined,
};

pub fn init(allocator: Allocator) !void {
    fs_context.allocator = allocator;
    fs_context.dir_list = std.ArrayList(u8).init(fs_context.allocator);
    fs_context.original_cwd = try std.fs.cwd().openDir(".", .{});

    try changeDir(".");
}

pub fn deinit() void {
    fs_context.allocator = undefined;
    fs_context.dir_list.deinit();
    fs_context.original_cwd.close();
}

pub fn changeDir(path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    try dir.setAsCwd();

    fs_context.dir_list.clearAndFree();

    var iter = dir.iterate();
    while (try iter.next()) |item| {
        try fs_context.dir_list.appendSlice(item.name);
        try fs_context.dir_list.append('\x00');
        try fs_context.dir_list.append('\n');
    }
}
