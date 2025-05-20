const std = @import("std");
const flst = @import("file_system.zig");
const Allocator = std.mem.Allocator;

pub const FileSortType = enum {
    default,
    alpha,
    unmanaged_alpha,
};

pub fn sortFiles(sort: FileSortType, arr: *std.ArrayList([]const u8)) void {
    switch (sort) {
        .default, .alpha => {
            std.mem.sort([]const u8, arr.items, {}, lessThanDir);
        },
        .unmanaged_alpha => std.mem.sort([]const u8, arr.items, {}, lessThanDir),
    }
}

fn lessThanDir(_: void, a: []const u8, b: []const u8) bool {
    const is_dir_a = flst.isDir(std.mem.span(@as([*c]const u8, @ptrCast(a)))) catch false;
    const is_dir_b = flst.isDir(std.mem.span(@as([*c]const u8, @ptrCast(b)))) catch false;

    if (is_dir_a != is_dir_b) {
        return is_dir_a;
    }

    return std.ascii.lessThanIgnoreCase(a, b);
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}
