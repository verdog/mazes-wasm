//! utilities

const std = @import("std");

// TODO add asserts about the anytype?
pub fn strBuf(comptime len: comptime_int, comptime str: anytype) [len]u8 {
    return str.* ++ ([_]u8{undefined} ** (len - str.len));
}

pub fn eString(comptime e: type, v: e) []const u8 {
    const tief = @typeInfo(e).Enum.fields;
    inline for (tief) |fld| {
        if (@enumToInt(v) == fld.value) return fld.name;
    }
    std.debug.panic("Couldn't stringify {}.\n", .{e});
}
