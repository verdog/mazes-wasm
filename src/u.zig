//! utilities

const std = @import("std");

// TODO add asserts about the anytype?
pub fn strBuf(comptime len: comptime_int, comptime str: anytype) [len]u8 {
    return str.* ++ ([_]u8{undefined} ** (len - str.len));
}

pub fn eString(comptime e: type, v: e) []const u8 {
    const tief = @typeInfo(e).Enum.fields;
    inline for (tief) |fld| {
        if (@intFromEnum(v) == fld.value) return fld.name;
    }
    std.debug.panic("Couldn't stringify {}.\n", .{e});
}

pub fn lerp(from: f64, to: f64, t: f64) f64 {
    std.debug.assert(t >= 0 and t <= 1);
    return from + t * (to - from);
}
