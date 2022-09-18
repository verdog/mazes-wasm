//! qanvas is a collection of data in memory representing an image.
//! it supports some basic drawing operations.
//! when written to disk, it is written in the form of a qoi image.

const std = @import("std");
const qoi = @import("qoi.zig");
const Allocator = std.mem.Allocator;

const Qixel = qoi.Qixel;

pub const Qanvas = struct {
    width: u32,
    height: u32,
    buf: []Qixel(qoi.RGB),
    allocator: Allocator,

    pub fn init(alloc: Allocator, width: u32, height: u32) !Qanvas {
        var q = Qanvas{
            .width = width,
            .height = height,
            .buf = try alloc.alloc(Qixel(qoi.RGB), width * height),
            .allocator = alloc,
        };

        const grid_scale = 16;

        for (q.buf) |*qix, i| {
            const row = @divTrunc(@divTrunc(i, width), grid_scale);
            const col = @divTrunc(i % width, grid_scale);
            if (row & 1 == col & 1) {
                // magenta
                qix.* = Qixel(qoi.RGB){};
            } else {
                // blank
                qix.* = Qixel(qoi.RGB){ .colors = .{ .red = 0, .green = 0, .blue = 0 } };
            }
        }

        return q;
    }

    pub fn deinit(this: Self) void {
        this.allocator.free(this.buf);
    }

    pub fn clear(this: Self, color: anytype) void {
        switch (@TypeOf(color)) {
            Qixel(qoi.RGB) => {
                for (this.buf) |*qix| {
                    qix.* = color;
                }
            },
            Qixel(qoi.HSV) => {
                return this.clear(Qixel(qoi.RGB){ .colors = color.colors.toRGB, .alpha = this.alpha });
            },
            else => @compileError(""),
        }
    }

    pub fn line(this: Self, color: Qixel(qoi.RGB), x1: u32, x2: u32, y1: u32, y2: u32) !void {
        const x_start = @as(i64, x1);
        const x_end = @as(i64, x2);
        const y_start = @as(i64, y1);
        const y_end = @as(i64, y2);

        // TODO bounds checking

        const dx = x_end - x_start;
        const dy = y_end - y_start;
        const iters = std.math.max(try std.math.absInt(dx), try std.math.absInt(dy));
        var i: u32 = 0;

        while (i < iters) : (i += 1) {
            var x = @intCast(usize, x_start + @divTrunc(i * dx, iters));
            var y = @intCast(usize, y_start + @divTrunc(i * dy, iters));
            this.buf[y * this.width + x] = color;
        }
    }

    pub fn fill(this: Self, color: Qixel(qoi.RGB), x1: u32, x2: u32, y1: u32, y2: u32) !void {
        const x_start = std.math.min(x1, x2);
        const x_end = std.math.max(x1, x2);
        var y_start = std.math.min(y1, y2);
        const y_end = std.math.max(y1, y2);

        // TODO bounds checking

        var x = x_start;

        while (y_start < y_end) : ({
            y_start += 1;
            x = x_start;
        }) {
            while (x < x_end) : (x += 1) {
                this.buf[y_start * this.width + x] = color;
            }
        }
    }

    pub fn encode(this: Self) ![]u8 {
        return try qoi.encode(this.buf, this.allocator, this.width, this.height, qoi.Channels.rgba, qoi.Colorspace.alpha_linear);
    }

    const Self = @This();
};

test "Test qoi" {
    _ = @import("qoi.zig");
}

test "Construct/Destruct Qanvas" {
    var alloc = std.testing.allocator;
    var q = try Qanvas.init(alloc, 1024, 1024);

    for (q.buf) |qix, i| {
        const row = @divTrunc(@divTrunc(i, q.width), 16);
        const col = @divTrunc(i % q.width, 16);
        if (row & 1 == col & 1) {
            // magenta
            try std.testing.expectEqual(Qixel{}, qix);
        } else {
            // blank
            try std.testing.expectEqual(Qixel{ .red = 0, .green = 0, .blue = 0 }, qix);
        }
    }

    defer q.deinit();
}
