const std = @import("std");

const grd = @import("grid.zig");
const maze = @import("mazes.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    var grid = try grd.Grid.init(alloc, 777, 64, 64);
    defer grid.deinit();

    try maze.AldousBroder.on(&grid);

    grid.distances = try grid.at(@divTrunc(grid.width, 2), @divTrunc(grid.height, 2)).?.distances();

    var txt = try grid.makeString();
    defer alloc.free(txt);
    std.debug.print("{s}\n", .{txt});

    var encoded = try grid.makeQoi(false);
    defer alloc.free(encoded);
    try stdout.print("{s}", .{encoded});
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
