//! implements a qoi encoder

const std = @import("std");
const builtin = @import("builtin");

pub const Header = packed struct {
    m: u8 = 'q',
    a: u8 = 'o',
    g: u8 = 'i',
    ic: u8 = 'f',
    /// stored in big endian
    width: u32,
    /// stored in big endian
    height: u32,
    channels: Channels,
    colorspace: Colorspace,

    const Channels = enum(u8) {
        rgb = 3,
        rgba = 4,
    };

    const Colorspace = enum(u8) {
        alpha_linear = 0,
        all_linear = 1,
    };

    pub fn init(width: u32, height: u32, channels: Channels, colorspace: Colorspace) Header {
        var w = width;
        var h = height;
        if (builtin.cpu.arch.endian() == std.builtin.Endian.Little) {
            w = @byteSwap(u32, w);
            h = @byteSwap(u32, h);
        }
        return Header{
            .width = w,
            .height = h,
            .channels = channels,
            .colorspace = colorspace,
        };
    }
};

test "Header properly constructed rbg/alphal" {
    var h = Header.init(2, 4, Header.Channels.rgb, Header.Colorspace.alpha_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 3, 0 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "Header properly constructed rbg/all" {
    var h = Header.init(2, 4, Header.Channels.rgb, Header.Colorspace.all_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 3, 1 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "Header properly constructed rbga/alphal" {
    var h = Header.init(2, 4, Header.Channels.rgba, Header.Colorspace.alpha_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 4, 0 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "Header properly constructed rbga/all" {
    var h = Header.init(2, 4, Header.Channels.rgba, Header.Colorspace.all_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 4, 1 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}
