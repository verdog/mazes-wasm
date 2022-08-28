const std = @import("std");

const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    const width = 64;
    const height = 64;

    var qanv = try qan.Qanvas.init(alloc, width, height);
    defer qanv.deinit();

    var prev = qanv.buf[0];

    for (qanv.buf) |*qix| {
        defer prev = qix.*;
        qix.* = .{ .red = prev.red +% 2, .green = prev.green, .blue = prev.blue };
    }

    var encoded = try qoi.encode(qanv.buf, alloc, width, height, qoi.Channels.rgb, qoi.Colorspace.alpha_linear);
    defer alloc.free(encoded);

    try stdout.print("{s}", .{encoded});
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
