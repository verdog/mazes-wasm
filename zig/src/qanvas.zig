//! qanvas is a collection of data in memory representing an image.
//! it supports some basic drawing operations.
//! when written to disk, it is written in the form of a qoi image.

const std = @import("std");
const qoi = @import("qoi.zig");
const Allocator = std.mem.Allocator;

pub const Qixel = struct {
    red: u8 = 255,
    green: u8 = 0,
    blue: u8 = 255,
    alpha: u8 = 255,
};

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

        for (q.buf) |*qix| {
            qix.* = Qixel{};
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
    var default_qix = Qixel{};

    for (q.buf) |qix| {
        try std.testing.expectEqual(default_qix, qix);
    }

    defer q.deinit();
}
