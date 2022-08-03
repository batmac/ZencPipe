const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const clap = @import("clap");
const C = @cImport({
    @cInclude("hydrogen.h");
});
const constants = @import("constants.zig");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

var master_key = mem.zeroes([C.hydro_pwhash_MASTERKEYBYTES:0]u8);
var backend = mem.zeroes([constants.DEFAULT_BUFFER_SIZE:0]u8);

const Context = struct {
    in: ?[]const u8 = null,
    out: ?[]const u8 = null,
    key: ?[C.hydro_secretbox_KEYBYTES:0]u8 = null,
    buf: [constants.DEFAULT_BUFFER_SIZE:0]u8 =
        mem.zeroes([constants.DEFAULT_BUFFER_SIZE:0]u8),
    fd_in: ?u8 = null,
    fd_out: ?u8 = null,
    encrypt: ?bool = null,
    has_key: bool = false,
};

pub fn main() anyerror!void {
    var password: [:0]u8 = "";

    comptime {
        // +1 to count the C string final zero.
        std.debug.assert(constants.HYDRO_CONTEXT.len + 1 == C.hydro_secretbox_CONTEXTBYTES);
    }

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();

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

    if (res.args.pass) |p| {
        // std.log.info("pass: {s}", .{p});
        mem.copy(u8, backend[0..], p[0..]);
        password = backend[0..p.len :0];
    }

    if (res.args.passfile) |p| {
        // std.log.info("passfile: {s}", .{p});
        var f = fs.cwd().openFile(p, fs.File.OpenFlags{ .mode = .read_only }) catch |err| {
            std.log.err("{s} {?}", .{ p, err });
            return;
        };
        // const content = try f.readToEndAlloc(gpa, 1024 * 1024);
        const content = try f.readToEndAllocOptions(gpa, 1024 * 1024, null, @alignOf(u8), 0);
        f.close();
        defer gpa.free(content);
        password = content;
        // std.log.err("pass: {s}", .{password});
    }

    std.log.info("length: {d}", .{password.len});
    var ctx = Context{};
    try derive_key(&ctx, &password);

    if (res.args.decrypt) {
        ctx.encrypt = false;
    }
    if (res.args.encrypt) {
        ctx.encrypt = true;
    }
    if (res.args.in) |in| {
        ctx.in = in;
    }
    if (res.args.out) |out| {
        ctx.in = out;
    }

    _ = try stream_decrypt(&ctx);
}

fn passgen() !void {
    var password = mem.zeroes([32:0]u8);
    var hex = mem.zeroes([32 * 2 + 1:0]u8);

    _ = C.hydro_random_buf(&password, password.len);
    // std.log.debug("{s}", .{password});
    _ = C.hydro_bin2hex(&hex, hex.len, &password, password.len);
    defer {
        _ = C.hydro_memzero(&password, password.len);
        _ = C.hydro_memzero(&hex, hex.len);
    }
    _ = try stdout.print("{s}\n", .{hex});
}

fn derive_key(ctx: *Context, password: *[:0]u8) !void {
    // zig fmt: off
    const x = C.hydro_pwhash_deterministic(
      @ptrCast([*c]u8, &ctx.key), C.hydro_secretbox_KEYBYTES,
      @ptrCast([*c]const u8, password), password.len,
      constants.HYDRO_CONTEXT, &master_key,
      constants.PWHASH_OPSLIMIT, constants.PWHASH_MEMLIMIT,
      constants.PWHASH_THREADS,
    );
    // zig fmt: on

    if (x != 0) {
        return error.PwHashingFailed;
    }

    C.hydro_memzero(@ptrCast([*c]u8, password), password.len);
}

fn stream_decrypt(ctx: *Context) !void {
    //const chunk_size_p = ctx.buf[0..];
    //const chunk = chunk_size_p + 4;
    //const chunk_id: u64 = 0;

    comptime {
        // +1 to count the C string final zero.
        std.debug.assert(ctx.buf.len + 1 >= 4 + C.hydro_secretbox_HEADERBYTES);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}

test "passgen" {
    try passgen();
}

//test "recursive" {
//    std.testing.refAllDeclsRecursive(@This());
//}
