const std = @import("std");

const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    const len = 32;

    var qanv = try qan.Qanvas.init(alloc, len, len);
    defer qanv.deinit();

    var encoded = try qoi.encode(qanv.buf, alloc, len, len, qoi.Channels.rgb, qoi.Colorspace.alpha_linear);
    defer alloc.free(encoded);

    std.debug.print("{s}", .{encoded});
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
