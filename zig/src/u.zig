//! utilities

// TODO add asserts about the anytype?
pub fn strBuf(comptime len: comptime_int, comptime str: anytype) [len]u8 {
    return str.* ++ ([_]u8{undefined} ** (len - str.len));
}
