const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub inline fn log(comptime format: []const u8, args: anytype) void {
    //stdout.print(format, args) catch unreachable;
    _ = comptime format;
    _ = comptime args;
}
