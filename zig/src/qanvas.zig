//! qanvas is a collection of data in memory representing an image.
//! it supports some basic drawing operations.
//! when written to disk, it is written in the form of a qoi image.

const std = @import("std");
const qoi = @import("qoi.zig");
const Allocator = std.mem.Allocator;

const Qixel = qoi.Qixel;

pub const Qanvas = struct {
    width: usize,
    height: usize,
    buf: []Qixel,
    allocator: Allocator,

    pub fn init(alloc: Allocator, width: usize, height: usize) !Qanvas {
        var q = Qanvas{
            .width = width,
            .height = height,
            .buf = try alloc.alloc(Qixel, width * height),
            .allocator = alloc,
        };

        const grid_scale = 16;

        for (q.buf) |*qix, i| {
            const row = @divTrunc(@divTrunc(i, width), grid_scale);
            const col = @divTrunc(i % width, grid_scale);
            if (row & 1 == col & 1) {
                // magenta
                qix.* = Qixel{};
            } else {
                // blank
                qix.* = Qixel{ .red = 0, .green = 0, .blue = 0 };
            }
        }

        return q;
    }

    pub fn deinit(this: Self) void {
        this.allocator.free(this.buf);
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
        if (row & 1 == 0 and col & 1 == 0) {
            // magenta
            try std.testing.expectEqual(Qixel{}, qix);
        } else {
            // blank
            try std.testing.expectEqual(Qixel{ .red = 0, .green = 0, .blue = 0 }, qix);
        }
    }

    defer q.deinit();
}
