const Grid = @import("grid.zig").Grid;
pub const BinaryTree = @import("binary_tree.zig").BinaryTree;
pub const Sidewinder = @import("sidewinder.zig").Sidewinder;
pub const AldousBroder = @import("aldous_broder.zig").AldousBroder;

const Error = error{
    NoSuchMaze,
};

pub fn onByName(name: []const u8, grid: *Grid) !void {
    const eq = @import("std").mem.startsWith;
    if (eq(u8, name, "AldousBroder")) return try AldousBroder.on(grid);
    if (eq(u8, name, "Sidewinder")) return try Sidewinder.on(grid);
    if (eq(u8, name, "BinaryTree")) return try BinaryTree.on(grid);

    return Error.NoSuchMaze;
}

test "Test mazes" {
    _ = @import("binary_tree.zig");
    _ = @import("sidewinder.zig");
    _ = @import("aldous_broder.zig");
}
