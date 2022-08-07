const std = @import("std");
const os = std.os;
const expect = std.testing.expect;

const stderr = std.io.getStdErr().writer();

pub inline fn log(comptime format: []const u8, args: anytype) void {
    // stderr.print(format, args) catch unreachable;
    _ = comptime format;
    _ = comptime args;
}

pub fn die(comptime format: []const u8, args: anytype) void {
    std.log.err(format, args);
    os.exit(1);
}

test "log" {
    // no panic please
    log("log test...", .{});
}
test "die" {
    const pid = try std.os.fork();
    if (pid == 0) {
        die("die test...", .{});
    } else {
        const result = std.os.waitpid(pid, 0);
        try expect((result.status >> 8) == 1);
    }
}
