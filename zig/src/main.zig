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
    _ = seed;
    try mazes.BinaryTree.on(&g, 777);

    var stringy = try g.makeString();
    defer alloc.free(stringy);

    std.debug.print("{s}", .{stringy});
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
}
