//! implements a qoi encoder

const std = @import("std");
const builtin = @import("builtin");

pub const EncodeError = error{
    QoiMalformedBuffer,
};

const InternalEncodeError = error{
    QoiNoRoom,
};

pub const Channels = enum(u8) {
    rgb = 3,
    rgba = 4,
};

pub const Colorspace = enum(u8) {
    alpha_linear = 0,
    all_linear = 1,
};

pub const Qixel = struct {
    red: u8 = 255,
    green: u8 = 0,
    blue: u8 = 255,
    alpha: u8 = 255,
};

pub const Chunks = struct {
    pub const Header = packed struct {
        magic: u32 = @bitCast(u32, @as([4]u8, .{ 'q', 'o', 'i', 'f' })),
        /// stored in big endian
        width: u32,
        /// stored in big endian
        height: u32,
        channels: Channels,
        colorspace: Colorspace,

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

    pub const RGB = packed struct {
        magic: u8 = 0b11111110,
        red: u8 = 0,
        green: u8 = 0,
        blue: u8 = 0,

        pub fn init(qix: Qixel) @This() {
            return @This(){ .red = qix.red, .green = qix.green, .blue = qix.blue };
        }
    };

    pub const Tailer = packed struct { magic: u64 = @bitCast(u64, @as([8]u8, .{ 0, 0, 0, 0, 0, 0, 0, 1 })) };
};

fn sizeOnDisk(comptime T: type) usize {
    return switch (@typeInfo(T)) {
        .Struct => |strct| blk: {
            if (strct.layout == .Packed) {
                break :blk @divExact(@typeInfo(strct.backing_integer.?).Int.bits, 8);
            } else {
                break :blk @sizeOf(T);
            }
        },
        .Int => |int| int.bits,
        else => @sizeOf(T),
    };
}

fn writeCursor(buffer: *[]u8, alloc: std.mem.Allocator, i: *usize, data: anytype) !void {
    const len = comptime sizeOnDisk(@TypeOf(data));
    if (i.* + len >= buffer.len) {
        buffer.* = try alloc.realloc(buffer.*, buffer.*.len * 2);
        return writeCursor(buffer, alloc, i, data);
    }

    std.mem.copy(u8, buffer.*[i.*..], &@bitCast([len]u8, data));
    i.* += len;
}

pub fn encode(buffer: []Qixel, alloc: std.mem.Allocator, width: u32, height: u32, channels: Channels, colorspace: Colorspace) ![]u8 {
    if (buffer.len == 0) {
        return EncodeError.QoiMalformedBuffer;
    }
    if (buffer.len != @as(usize, width) * @as(usize, height)) {
        return EncodeError.QoiMalformedBuffer;
    }

    // random heuristic I made up for starting size...
    var result = try alloc.alloc(u8, @divTrunc(width * height, 2));
    var i: usize = 0;

    const Header = Chunks.Header;
    const Tailer = Chunks.Tailer;
    const RGB = Chunks.RGB;

    try writeCursor(&result, alloc, &i, Header.init(width, height, channels, colorspace));

    // TODO: make this not super bad
    for (buffer) |qix| {
        if (channels == .rgb) {
            try writeCursor(&result, alloc, &i, RGB.init(qix));
        } else {
            // rgba
        }
    }

    try writeCursor(&result, alloc, &i, Tailer{});

    result = try alloc.realloc(result, i);

    return result;
}

test "Header properly constructed rbg/alphal" {
    var h = Chunks.Header.init(2, 4, Channels.rgb, Colorspace.alpha_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 3, 0 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "Header properly constructed rbg/all" {
    var h = Chunks.Header.init(2, 4, Channels.rgb, Colorspace.all_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 3, 1 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "Header properly constructed rbga/alphal" {
    var h = Chunks.Header.init(2, 4, Channels.rgba, Colorspace.alpha_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 4, 0 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "Header properly constructed rbga/all" {
    var h = Chunks.Header.init(2, 4, Channels.rgba, Colorspace.all_linear);
    var bytes: [14]u8 = .{ 'q', 'o', 'i', 'f', 0, 0, 0, 2, 0, 0, 0, 4, 4, 1 };

    try std.testing.expectEqualSlices(u8, &bytes, &@bitCast([14]u8, h));
}

test "sizeOnDisk returns expected values for qoi data structures" {
    try std.testing.expectEqual(@as(usize, 14), sizeOnDisk(Chunks.Header));
    try std.testing.expectEqual(@as(usize, 8), sizeOnDisk(Chunks.Tailer));
}

test "Encode errors on empty buffer" {
    var buf: []Qixel = &.{};
    var alloc = std.testing.allocator;

    try std.testing.expectError(EncodeError.QoiMalformedBuffer, encode(buf, alloc, 0, 0, Channels.rgba, Colorspace.alpha_linear));
}

test "Encode errors on bad dimensions" {
    var buf = [_]Qixel{ Qixel{}, Qixel{}, Qixel{}, Qixel{} };
    var alloc = std.testing.allocator;

    try std.testing.expectError(EncodeError.QoiMalformedBuffer, encode(&buf, alloc, 0, 0, Channels.rgba, Colorspace.alpha_linear));
    try std.testing.expectError(EncodeError.QoiMalformedBuffer, encode(&buf, alloc, 4, 0, Channels.rgba, Colorspace.alpha_linear));
    try std.testing.expectError(EncodeError.QoiMalformedBuffer, encode(&buf, alloc, 0, 4, Channels.rgba, Colorspace.alpha_linear));
    try std.testing.expectError(EncodeError.QoiMalformedBuffer, encode(&buf, alloc, 3, 3, Channels.rgba, Colorspace.alpha_linear));
}

test "Encode begins with a header and ends with a tailer" {
    var alloc = std.testing.allocator;
    var buf = try alloc.alloc(Qixel, 128 * 128);
    defer alloc.free(buf);
    var encoded = try encode(buf, alloc, 128, 128, Channels.rgb, Colorspace.alpha_linear);
    defer alloc.free(encoded);

    var expected_header = Chunks.Header.init(128, 128, Channels.rgb, Colorspace.alpha_linear);

    try std.testing.expectEqualSlices(u8, &@bitCast([14]u8, expected_header), encoded[0..14]);
    try std.testing.expectEqualSlices(u8, &@bitCast([8]u8, Chunks.Tailer{}), encoded[encoded.len - 8 .. encoded.len]);
}
