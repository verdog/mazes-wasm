const std = @import("std");
const Grid = @import("grid.zig").Grid;

var heap = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    var g = try Grid.init(heap.allocator(), 6, 6);
    defer g.deinit();
}
