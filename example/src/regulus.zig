const std = @import("std");

pub const Modes = enum {
    select,
    save,
};

pub const FileDialogContext = struct {
    buf: [:0]u8,
    output: [:0]u8,
    mode: Modes,
    success: bool,
    state: enum {
        ready,
        locked,
        finished,
    },

    pub fn new(buf: [:0]u8) @This() {
        return .{
            .buf = buf,
            .output = buf,
            .mode = undefined,
            .success = false,
            .state = .ready,
        };
    }

    pub fn fail(self: *@This()) void {
        @memset(self.buf, 0);
        self.output = self.buf;
        self.success = false;
        self.state = .finished;
    }

    pub fn clear(self: *@This()) void {
        @memset(self.buf, 0);
        self.output = self.buf;
        self.mode = undefined;
        self.success = false;
        self.state = .ready;
    }
};

fn regulusRun(allocator: std.mem.Allocator, mode: Modes, context: *FileDialogContext) !void {
    const command = &[_][]const u8{
        "./regulus",
        switch (mode) {
            .select => "--file-dialog-select",
            .save => "--file-dialog-save",
        },
    };

    // Run regulus as child process
    var child = std.process.Child.init(command, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    _ = try child.spawn(); // Start the process
    defer {
        _ = child.kill() catch @panic("File dialog failed");
    }

    // Collect output from stdout
    const stdout = child.stdout.?.reader();
    _ = try stdout.readAll(context.output);

    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.log.err("Command failed with exit code: {d}\n", .{code});
                context.fail();
                return;
            }
        },
        else => {
            std.log.err("Process terminated abnormally\n", .{});
            context.fail();
            return;
        }
    }

    if (context.output[0] == 0) {
        context.fail();
        return;
    }

    const output_end = std.mem.indexOfScalar(u8, context.output, 0) orelse context.output.len;
    context.output = context.output[0..output_end:0];

    context.success = true;
    context.state = .finished;
}

pub fn open(allocator: std.mem.Allocator, mode: Modes, context: *FileDialogContext) !void {
    if (context.state == .ready) {
        context.state = .locked;
        context.mode = mode;
        _ = try std.Thread.spawn(.{}, regulusRun, .{allocator, mode, context});
    }
}
