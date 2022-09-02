const std = @import("std");

const grd = @import("grid.zig");
const maze = @import("mazes.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    var grid = try grd.Grid.init(alloc, 8, 1024);
    defer grid.deinit();

    try maze.Sidewinder.on(&grid, 11);

    grid.distances = try grid.at(0, 0).?.distances();
    var path = try grid.distances.?.pathTo(grid.at(grid.width - 1, grid.height - 1).?);
    grid.distances.?.deinit();
    grid.distances = path;

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
