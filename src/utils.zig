const std = @import("std");
const os = std.os;
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
