const std = @import("std");
const regulus = @import("regulus.zig");

pub fn main() !void {
    var dba = std.heap.DebugAllocator(.{}){};
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    var regulus_context_buf = std.mem.zeroes([4096:0]u8);
    var regulus_context = regulus.FileDialogContext.new(&regulus_context_buf);

    try regulus.open(allocator, .select, &regulus_context);

    std.debug.print("Waiting...\n", .{});

    while(true) {
        if (regulus_context.state == .finished) {
            if (regulus_context.success) {
                std.debug.print("Regulus output: {s}\n", .{regulus_context.output});
            } else {
                std.debug.print("Failed to get output!\n", .{});
            }
            regulus_context.clear();
            break;
        }
    }
}
