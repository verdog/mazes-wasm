//! implements a qoi encoder

const std = @import("std");
const builtin = @import("builtin");
const u = @import("u.zig");

pub const EncodeError = error{
    QoiMalformedBuffer,
};

const InternalEncodeError = error{
    QoiBadChunk,
};

pub const Channels = enum(u8) {
    rgb = 3,
    rgba = 4,
};

pub const Colorspace = enum(u8) {
    alpha_linear = 0,
    all_linear = 1,
};

pub const RGB = struct {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,

    pub fn lerp(this: RGB, other: RGB, t: f64) RGB {
        // TODO
        _ = other;
        _ = t;
        return this;
    }
};

pub const HSV = struct {
    hue: f32 = 0,
    saturation: f32 = 0,
    value: f32 = 0,

    pub fn lerp(this: HSV, other: HSV, t: f64) HSV {
        var dhue = other.hue - this.hue;
        dhue = @mod(dhue + 180, 360) - 180;

        return .{
            .hue = @mod(@floatCast(f32, u.lerp(this.hue, this.hue + dhue, t)), 360),
            .saturation = @floatCast(f32, u.lerp(this.saturation, other.saturation, t)),
            .value = @floatCast(f32, u.lerp(this.value, other.value, t)),
        };
    }

    pub fn to(hsv: HSV, comptime Space: type) Space {
        switch (Space) {
            RGB => {
                std.debug.assert(hsv.hue >= 0);
                std.debug.assert(hsv.hue < 360);
                std.debug.assert(hsv.saturation >= 0);
                std.debug.assert(hsv.saturation < 1);
                std.debug.assert(hsv.value >= 0);
                std.debug.assert(hsv.value < 1);

                const chroma = hsv.saturation * hsv.value;
                const hprime = hsv.hue / 60;
                const component = blk: {
                    const c = @mod(hprime, 2.0) - 1.0;
                    break :blk std.math.fabs(c);
                };
                const x = chroma * (1 - component);

                const uchroma = @floatToInt(u8, chroma * 256);
                const ux = @floatToInt(u8, x * 256);

                var rgb =
                    if (hprime < 1) RGB{ .red = uchroma, .green = ux, .blue = 0 } else if (hprime < 2) RGB{ .red = ux, .green = uchroma, .blue = 0 } else if (hprime < 3) RGB{ .red = 0, .green = uchroma, .blue = ux } else if (hprime < 4) RGB{ .red = 0, .green = ux, .blue = uchroma } else if (hprime < 5) RGB{ .red = ux, .green = 0, .blue = uchroma } else if (hprime < 6) RGB{ .red = uchroma, .green = 0, .blue = ux } else unreachable;

                const m = @floatToInt(u8, hsv.value * 256) - uchroma;
                rgb.red += m;
                rgb.green += m;
                rgb.blue += m;

                return rgb;
            },
            else => @compileError(""),
        }
    }
};

pub fn Qixel(comptime Space: type) type {
    return struct {
        colors: Space = Space{},
        alpha: u8 = 255,

        pub fn equal(this: @This(), other: @This()) bool {
            return std.mem.eql(u8, std.mem.asBytes(&this.colors), std.mem.asBytes(&other.colors)) and this.alpha == other.alpha;
        }

        pub fn lerp(this: @This(), other: @This(), t: f64) @This() {
            std.debug.assert(t >= 0 and t <= 1);
            return .{
                .colors = this.colors.lerp(other.colors, t),
                .alpha = other.alpha, // TODO should lerp
            };
        }

        pub fn to(this: @This(), comptime Spc: type) Qixel(Spc) {
            return .{
                .colors = this.colors.to(Spc),
                .alpha = this.alpha,
            };
        }
    };
}

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
                w = @byteSwap(w);
                h = @byteSwap(h);
            }
            return Header{
                .width = w,
                .height = h,
                .channels = channels,
                .colorspace = colorspace,
            };
        }
    };

    pub const qRGB = packed struct {
        magic: u8 = 0b11111110,
        red: u8 = 0,
        green: u8 = 0,
        blue: u8 = 0,

        pub fn init(qix: Qixel(RGB)) @This() {
            return @This(){ .red = qix.colors.red, .green = qix.colors.green, .blue = qix.colors.blue };
        }
    };

    pub const RGBA = packed struct {
        magic: u8 = 0b11111111,
        red: u8 = 0,
        green: u8 = 0,
        blue: u8 = 0,
        alpha: u8 = 0,

        pub fn init(qix: Qixel(RGB)) @This() {
            return @This(){ .red = qix.colors.red, .green = qix.colors.green, .blue = qix.colors.blue, .alpha = qix.alpha };
        }
    };

    pub const Index = packed struct {
        index: u6,
        magic: u2 = 0b00,

        pub fn init(idx: u6) @This() {
            return @This(){ .index = idx };
        }
    };

    pub const Diff = packed struct {
        db: u2,
        dg: u2,
        dr: u2,
        magic: u2 = 0b01,

        fn i2u(in: i2) u2 {
            return switch (in) {
                -2 => 0b00,
                -1 => 0b01,
                0 => 0b10,
                1 => 0b11,
            };
        }

        pub fn init(dr: i2, dg: i2, db: i2) @This() {
            return @This(){
                .dr = i2u(dr),
                .dg = i2u(dg),
                .db = i2u(db),
            };
        }
    };

    pub const Luma = packed struct {
        db: u4,
        dr: u4,
        dg: u6,
        magic: u2 = 0b10,

        pub fn init(dr: i4, dg: i6, db: i4) [2]u8 {
            var l = Luma{ .dr = @intCast(u4, @as(i5, dr) + 8), .dg = @intCast(u6, @as(i7, dg) + 32), .db = @intCast(u4, @as(i5, db) + 8) };
            return .{ (@as(u8, l.magic) << 6) | l.dg, (@as(u8, l.dr) << 4) | l.db };
        }
    };

    pub const Run = packed struct {
        run: u6,
        magic: u2 = 0b11,

        pub fn init(run: u6) @This() {
            // runs are stored with a bias of -1
            return .{
                .run = run - 1,
            };
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

fn hash(qix: Qixel(RGB)) u6 {
    // a pixel of all 255s will add up to 6630, so u16s can handle the math
    return @truncate(u6, @as(u16, qix.colors.red) * 3 + @as(u16, qix.colors.green) * 5 + @as(u16, qix.colors.blue) * 7 + @as(u16, qix.alpha) * 11);
}

pub fn encode(buffer: []Qixel(RGB), alloc: std.mem.Allocator, width: u32, height: u32, channels: Channels, colorspace: Colorspace) ![]u8 {
    if (buffer.len == 0) {
        return EncodeError.QoiMalformedBuffer;
    }
    if (buffer.len != @as(usize, width) * @as(usize, height)) {
        return EncodeError.QoiMalformedBuffer;
    }

    // random heuristic I made up for starting size...
    var result = try alloc.alloc(u8, @divTrunc(width * height, 2));
    var i: usize = 0;

    {
        const qRGB = Chunks.qRGB;
        const RGBA = Chunks.RGBA;
        const Run = Chunks.Run;
        const Index = Chunks.Index;
        const Diff = Chunks.Diff;
        const Luma = Chunks.Luma;

        var prev = Qixel(RGB){ .colors = .{ .red = 0, .green = 0, .blue = 0 }, .alpha = 255 };
        var seen: [64]Qixel(RGB) = .{.{ .colors = .{ .red = 0, .green = 0, .blue = 0 }, .alpha = 0 }} ** 64;
        var current_run: u6 = 0;

        try writeCursor(&result, alloc, &i, Chunks.Header.init(width, height, channels, colorspace));

        for (buffer) |qix, j| {
            // priority:
            // 1. run
            // 2. index
            // 3. diff
            // 4. luma
            // 5. RGB
            // 6. RGBA

            // end run?
            if (prev.equal(qix)) {
                // std.debug.print("run...\n", .{});
                current_run += 1;
                if (current_run == 62 or j == buffer.len - 1) {
                    // close run; hit limit
                    // std.debug.print("close run; limit {}\n", .{current_run});
                    try writeCursor(&result, alloc, &i, Run.init(current_run));
                    current_run = 0;
                }
            } else {
                if (current_run > 0) {
                    // close run; not a match
                    // std.debug.print("close run; not a match {}\n", .{current_run});
                    try writeCursor(&result, alloc, &i, Run.init(current_run));
                    current_run = 0;
                }

                if (seen[hash(qix)].equal(qix)) {
                    // index
                    // std.debug.print("index\n", .{});
                    try writeCursor(&result, alloc, &i, Index.init(hash(qix)));
                } else {
                    seen[hash(qix)] = qix;
                    if (prev.alpha == qix.alpha) {
                        // check for a diff
                        var dr = @as(i16, qix.colors.red) - @as(i16, prev.colors.red);
                        var dg = @as(i16, qix.colors.green) - @as(i16, prev.colors.green);
                        var db = @as(i16, qix.colors.blue) - @as(i16, prev.colors.blue);

                        var dg_r = dr - dg;
                        var dg_b = db - dg;

                        if (dr > -3 and dr < 2 and
                            dg > -3 and dg < 2 and
                            db > -3 and db < 2)
                        {
                            // Diff
                            // std.debug.print("diff\n", .{});
                            try writeCursor(&result, alloc, &i, Diff.init(@truncate(i2, dr), @truncate(i2, dg), @truncate(i2, db)));
                        } else if (dg_r > -9 and dg_r < 8 and
                            dg > -33 and dg < 32 and
                            dg_b > -9 and dg_b < 8)
                        {
                            // Luma
                            // std.debug.print("luma {} {} {}\n", .{ dg_r, dg, dg_b });
                            try writeCursor(&result, alloc, &i, Luma.init(@truncate(i4, dg_r), @truncate(i6, dg), @truncate(i4, dg_b)));
                        } else {
                            // RGB
                            // std.debug.print("rgb\n", .{});
                            try writeCursor(&result, alloc, &i, qRGB.init(qix));
                        }
                    } else {
                        // RGBA
                        // std.debug.print("rgba\n", .{});
                        try writeCursor(&result, alloc, &i, RGBA.init(qix));
                    }
                }
            }
            prev = qix;
        }
    }

    try writeCursor(&result, alloc, &i, Chunks.Tailer{});

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

test "Run properly constructed" {
    var r = Chunks.Run.init(1);
    try std.testing.expectEqual(@as(u8, 0b11000000), @bitCast(u8, r));
    var r2 = Chunks.Run.init(16);
    try std.testing.expectEqual(@as(u8, 0b11001111), @bitCast(u8, r2));
}

test "Index properly constructed" {
    var i = Chunks.Index.init(1);
    try std.testing.expectEqual(@as(u8, 0b00000001), @bitCast(u8, i));
}

test "Luma properly constructed" {
    var l = Chunks.Luma.init(-4, 8, -6);
    try std.testing.expectEqualSlices(u8, &.{ 0b10_101000, 0b0100_0010 }, &@bitCast([2]u8, l));
}

test "sizeOnDisk returns expected values for qoi data structures" {
    try std.testing.expectEqual(@as(usize, 14), sizeOnDisk(Chunks.Header));
    try std.testing.expectEqual(@as(usize, 8), sizeOnDisk(Chunks.Tailer));
    try std.testing.expectEqual(@as(usize, 4), sizeOnDisk(Chunks.RGB));
    try std.testing.expectEqual(@as(usize, 5), sizeOnDisk(Chunks.RGBA));
    try std.testing.expectEqual(@as(usize, 1), sizeOnDisk(Chunks.Index));
    try std.testing.expectEqual(@as(usize, 1), sizeOnDisk(Chunks.Diff));
    try std.testing.expectEqual(@as(usize, 1), sizeOnDisk(Chunks.Run));
    try std.testing.expectEqual(@as(usize, 2), sizeOnDisk(Chunks.Luma));
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
