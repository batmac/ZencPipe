const std = @import("std");
const clap = @import("clap");
const hydro = @cImport({
    @cInclude("hydrogen.h");
});

pub fn main() anyerror!void {
    // Note that info level log messages are by default printed only in Debug
    // and ReleaseSafe build modes.
    std.log.info("All your codebase are belong to us.", .{});
    const r = hydro.hydro_init();
    if (r != 0) {
        std.log.err("hydro_init error {}", .{r});
    }

}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
