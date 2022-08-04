const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const clap = @import("clap");
const C = @cImport({
    @cInclude("hydrogen.h");
});
const constants = @import("constants.zig");
const utils = @import("utils.zig");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

const master_key = mem.zeroes([C.hydro_pwhash_MASTERKEYBYTES:0]u8);
var password_buf = mem.zeroes([constants.DEFAULT_BUFFER_SIZE:0]u8);

const Context = struct {
    in: ?[]const u8 = null,
    out: ?[]const u8 = null,
    key: ?[C.hydro_secretbox_KEYBYTES:0]u8 = null,
    buf: [constants.DEFAULT_BUFFER_SIZE:0]u8 =
        mem.zeroes([constants.DEFAULT_BUFFER_SIZE:0]u8),
    file_in: ?std.fs.File.Reader = stdin,
    file_out: ?std.fs.File.Writer = stdout,
    encrypt: ?bool = null,
    has_key: bool = false,
};

pub fn main() anyerror!void {
    var password: [:0]u8 = "";
    var ctx = Context{};

    comptime {
        std.debug.assert(constants.HYDRO_CONTEXT.len == C.hydro_secretbox_CONTEXTBYTES);
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

    utils.log("hydro_init...\n", .{});
    const r = C.hydro_init();
    if (r != 0) {
        std.log.err("hydro_init error {}", .{r});
        return error.HydroInit;
    }

    if (res.args.passgen) {
        return passgen();
    }

    if (res.args.pass) |p| {
        // std.log.info("pass: {s}", .{p});
        mem.copy(u8, password_buf[0..], p[0..]);
        password = password_buf[0..p.len :0];
        try derive_key(&ctx, &password);
    }

    if (res.args.passfile) |p| {
        utils.log("read passfile...\n", .{});
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
        try derive_key(&ctx, &password);
    }

    utils.log("password : {s}\n", .{password});
    utils.log("password length: {d}\n", .{password.len});

    if (res.args.decrypt) {
        ctx.encrypt = false;
    }
    if (res.args.encrypt) {
        ctx.encrypt = true;
    }
    if (res.args.in) |in| {
        ctx.in = in;
        return error.TODO;
    }
    if (res.args.out) |out| {
        ctx.in = out;
        return error.TODO;
    }

    if (!ctx.has_key) {
        return error.KeyNotSet;
    }
    if (ctx.encrypt) |encrypt| {
        if (encrypt) {
            _ = try stream_encrypt(&ctx);
        } else {
            _ = try stream_decrypt(&ctx);
        }
    } else {
        std.log.err("please choose -d or -e", .{});
        return error.ModeNotChosen;
    }
}

fn passgen() !void {
    var password = comptime mem.zeroes([32:0]u8);
    var hex = comptime mem.zeroes([32 * 2 + 1:0]u8);

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
    utils.log("derive_key...\n", .{});
    if (ctx.has_key) {
        return error.KeyAlreadySet;
    }
    // zig fmt: off
    const x = C.hydro_pwhash_deterministic(
      @ptrCast([*c]u8, &ctx.key), C.hydro_secretbox_KEYBYTES,
      @ptrCast([*c]const u8, password.*), password.len,
      constants.HYDRO_CONTEXT, &master_key,
      constants.PWHASH_OPSLIMIT, constants.PWHASH_MEMLIMIT,
      constants.PWHASH_THREADS,
    );
    // zig fmt: on
    utils.log("end derive_key...\n", .{});

    if (x != 0) {
        return error.PwHashingFailed;
    }

    C.hydro_memzero(@ptrCast([*c]u8, password), password.len);
    ctx.has_key = true;
}

fn stream_decrypt(ctx: *Context) !void {
    utils.log("stream_decrypt...\n", .{});

    //const chunk = chunk_size_p + 4;

    // +1 to count the C string final zero.
    comptime std.debug.assert(ctx.buf.len + 1 >= 4 + C.hydro_secretbox_HEADERBYTES);
    const max_chunk_size = comptime ctx.buf.len - 4 - C.hydro_secretbox_HEADERBYTES;
    comptime std.debug.assert(max_chunk_size <= 0x7fffffff);

    var chunk_id: u64 = 0;
    const in = ctx.file_in.?;

    while (true) {
        const chunk_size = try in.readIntLittle(u32);
        utils.log("chunk_size={d} (max={d})\n", .{ chunk_size, max_chunk_size });

        if (chunk_size == 0) {
            break;
        }
        if (chunk_size > max_chunk_size) {
            return error.ChunkSizeTooLarge;
        }

        const bytes_read = try in.readAll(ctx.buf[0 .. chunk_size + C.hydro_secretbox_HEADERBYTES]);
        utils.log("bytes_read={d}\n", .{bytes_read});

        if (bytes_read != chunk_size + C.hydro_secretbox_HEADERBYTES) {
            return error.ReadChunkTooShort;
        }

        // zig fmt: off
        const r = C.hydro_secretbox_decrypt(
            @ptrCast(*anyopaque,&ctx.buf),
            @ptrCast([*c]const u8,&ctx.buf),
            chunk_size + C.hydro_secretbox_HEADERBYTES,
            chunk_id,
            constants.HYDRO_CONTEXT,
            @ptrCast([*c]const u8,&ctx.key)
        );
        // zig fmt: on
        utils.log("r={d}\n", .{r});
        if (r != 0) {
            utils.log("Unable to decrypt chunk #{d}\n", .{chunk_id});
            break;
        }

        try stdout.writeAll(ctx.buf[0..chunk_size]);

        chunk_id += 1;
    }
}

fn stream_encrypt(ctx: *Context) !void {
    _ = ctx;
    return error.TODO;
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
