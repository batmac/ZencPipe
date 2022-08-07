const expect = @import("std").testing.expect;

pub const MIN_BUFFER_SIZE = 512;
pub const MAX_BUFFER_SIZE = 0x7fffffff;
pub const DEFAULT_BUFFER_SIZE = (1 * 1024 * 1024);
pub const HYDRO_CONTEXT = "EncPipe\x00";
pub const PWHASH_OPSLIMIT = 1000000;
pub const PWHASH_MEMLIMIT = 0;
pub const PWHASH_THREADS = 1;

test "buffer" {
    try expect(DEFAULT_BUFFER_SIZE >= MIN_BUFFER_SIZE);
    try expect(DEFAULT_BUFFER_SIZE <= MAX_BUFFER_SIZE);
}
test "context" {
    // HYDRO_CONTEXT must be a valid C string
    try expect(HYDRO_CONTEXT[HYDRO_CONTEXT.len - 1] == 0);
}
