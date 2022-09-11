const Grid = @import("grid.zig").Grid;
const HexGrid = @import("hex_grid.zig").HexGrid;

pub const BinaryTree = @import("binary_tree.zig").BinaryTree;
pub const Sidewinder = @import("sidewinder.zig").Sidewinder;
pub const AldousBroder = @import("aldous_broder.zig").AldousBroder;
pub const Wilson = @import("wilson.zig").Wilson;
pub const Fast = @import("fast.zig").Fast;
pub const HuntAndKill = @import("hunt_and_kill.zig").HuntAndKill;
pub const RecursiveBacktracker = @import("recursive_backtracker.zig").RecursiveBacktracker;

const Error = error{
    NoSuchMaze,
};

// TODO make this dispatch more clever

pub fn onByName(comptime GridType: type, name: []const u8, grid: anytype) !void {
    switch (GridType) {
        Grid => return try onByName_square(name, grid),
        HexGrid => return try onByName_hex(name, grid),
        else => @import("std").debug.panic("Unsupported grid type {}\n", .{GridType}),
    }
}

fn onByName_square(name: []const u8, grid: *Grid) !void {
    const eq = @import("std").mem.startsWith;
    if (eq(u8, name, "AldousBroder")) return try AldousBroder.on(grid);
    if (eq(u8, name, "Sidewinder")) return try Sidewinder.on(grid);
    if (eq(u8, name, "BinaryTree")) return try BinaryTree.on(grid);
    if (eq(u8, name, "Wilson")) return try Wilson.on(grid);
    if (eq(u8, name, "Fast")) return try Fast.on(grid);
    if (eq(u8, name, "HuntAndKill")) return try HuntAndKill.on(grid);
    if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);

    return Error.NoSuchMaze;
}

fn onByName_hex(name: []const u8, grid: *HexGrid) !void {
    const eq = @import("std").mem.startsWith;
    if (eq(u8, name, "AldousBroder")) return try AldousBroder.on(grid);
    if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);
    return Error.NoSuchMaze;
}

test "Test mazes" {
    _ = @import("binary_tree.zig");
    _ = @import("sidewinder.zig");
    _ = @import("aldous_broder.zig");
    _ = @import("wilson.zig");
    _ = @import("fast.zig");
    _ = @import("hunt_and_kill.zig");
    _ = @import("recursive_backtracker.zig");
}
