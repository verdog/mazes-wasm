const std = @import("std");

const grd = @import("grid.zig");
const maze = @import("mazes.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    var grid = try grd.Grid.init(alloc, 32, 16);
    defer grid.deinit();

    try maze.Sidewinder.on(&grid, 1);

    var txt = try grid.makeString();
    defer alloc.free(txt);
    std.debug.print("{s}\n", .{txt});

    var encoded = try grid.makeQoi();
    defer alloc.free(encoded);
    try stdout.print("{s}", .{encoded});
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
