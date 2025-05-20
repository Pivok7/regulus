const std = @import("std");
const builtin = @import("builtin");
const util = @import("util.zig");
const debug_mode = @import("main.zig").debug_mode;
const Allocator = std.mem.Allocator;

pub var fs_context = struct{
    allocator: Allocator,
    dir_list: std.ArrayList([]const u8),
    original_cwd: std.fs.Dir,
} {
    .allocator = undefined,
    .dir_list = undefined,
    .original_cwd = undefined,
};

pub fn init(allocator: Allocator) !void {
    fs_context.allocator = allocator;
    fs_context.dir_list = std.ArrayList([]const u8).init(fs_context.allocator);
    fs_context.original_cwd = try std.fs.cwd().openDir(".", .{});

    try changeDir(".");
}

pub fn deinit() void {
    defer fs_context.allocator = undefined;
    for (fs_context.dir_list.items) |item| {
        fs_context.allocator.free(item);
    }
    fs_context.dir_list.deinit();
    fs_context.original_cwd.close();
}

pub fn changeDir(path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    try dir.setAsCwd();

    for (fs_context.dir_list.items) |item| {
        fs_context.allocator.free(item);
    }
    fs_context.dir_list.clearAndFree();

    var iter = dir.iterate();
    while (try iter.next()) |item| {
        const slice = try fs_context.allocator.alloc(u8, item.name.len + 1);
        std.mem.copyForwards(u8, slice, item.name);
        slice[item.name.len] = '\x00';
        try fs_context.dir_list.append(slice);
    }
    util.sortFiles(.alpha, &fs_context.dir_list);
}

pub fn isDir(file_name: []const u8) !bool {
    if (builtin.target.os.tag == .windows) {
        // Windows is annoying and stat() doesn't tell me 
        // if something is a Dir or File so I had to do this
        const file_test = std.fs.cwd().openFile(file_name, .{}) catch |err| switch (err) {
                error.IsDir => null,
                else => return false,
        };

        if (file_test == null) {
            return true;
        } else {
            return false;
        }
    } else {
        const stat = std.fs.cwd().statFile(file_name) catch {
            return false;
        };
        switch (stat.kind) {
            .directory => return true,
            .file => return false,
            else => return false,
        }
    }
}
