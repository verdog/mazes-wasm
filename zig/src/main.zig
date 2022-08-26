const std = @import("std");
const Grid = @import("grid.zig").Grid;
const mazes = @import("mazes.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    var g = try Grid.init(alloc, 12, 12);
    defer g.deinit();

    var seed = std.time.milliTimestamp();
    try mazes.Sidewinder.on(&g, seed);

    var s = try g.makeString();
    defer alloc.free(s);

    std.debug.print("{s}", .{s});
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
