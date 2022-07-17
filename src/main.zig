const std = @import("std");
const clap = @import("clap");
const C = @cImport({
    @cInclude("hydrogen.h");
});

pub fn main() anyerror!void {
    // Note that info level log messages are by default printed only in Debug
    // and ReleaseSafe build modes.
    // std.log.info("All your codebase are belong to us.", .{});
    const params = comptime clap.parseParamsComptime(
        \\-G, --passgen          generate a random password
        \\-e, --encrypt          encryption mode
        \\-d, --decrypt          decryption mode
        \\-p, --pass <password>  use <password>
        \\-P, --passfile <file>  read password from <file>
        \\-i, --in <file>        read input from <file>
        \\-o, --out <file>       write output to <file>
        \\-h, --help             print this message
        \\
    );
    const parsers = comptime .{
        .password = clap.parsers.string,
        .file = clap.parsers.string,
    };
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();
    if (res.args.help) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    const r = C.hydro_init();
    if (r != 0) {
        std.log.err("hydro_init error {}", .{r});
    }

    if (res.args.passgen) {
        return passgen();
    }
}

fn passgen() !void {
    var password = [_]u8{0} ** 32;
    var hex = [_]u8{0} ** (32 * 2 + 1);

    _ = C.hydro_random_buf(&password, password.len);
    // std.log.debug("{s}", .{password});
    _ = C.hydro_bin2hex(&hex, hex.len, &password, password.len);
    defer {
        _ = C.hydro_memzero(&password, password.len);
        _ = C.hydro_memzero(&hex, hex.len);
    }
    const stdout = std.io.getStdOut().writer();
    _ = try stdout.print("{s}\n", .{hex});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}

test "passgen" {
    try passgen();
}
