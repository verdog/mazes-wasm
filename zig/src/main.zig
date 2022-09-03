const std = @import("std");

const grd = @import("grid.zig");
const maze = @import("mazes.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    defer _ = heap.detectLeaks();

    var grid = try grd.Grid.init(alloc, 8, 64);
    defer grid.deinit();

    try maze.Sidewinder.on(&grid, 777);

    grid.distances = try grid.at(0, 0).?.distances();

    {
        // find longest path
        var far = grid.distances.?.max();
        var far_dists = try far.cell.distances();
        defer far_dists.deinit();
        var final = far_dists.max();
        var final_dists = try final.cell.distances();
        defer final_dists.deinit();

        grid.distances.?.deinit();
        grid.distances = try final_dists.pathTo(far.cell);
    }

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
