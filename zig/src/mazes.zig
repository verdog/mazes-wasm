pub const Grid = @import("grid.zig").Grid;
pub const Cell = @import("grid.zig").Cell;
pub const HexGrid = @import("hex_grid.zig").HexGrid;
pub const HexCell = @import("hex_grid.zig").HexCell;
pub const TriGrid = @import("tri_grid.zig").TriGrid;
pub const TriCell = @import("tri_grid.zig").TriCell;
pub const UpsilonGrid = @import("upsilon_grid.zig").UpsilonGrid;
pub const UpsilonCell = @import("upsilon_grid.zig").UpsilonCell;

pub const Distances = @import("grid.zig").Distances;

pub const BinaryTree = @import("binary_tree.zig").BinaryTree;
pub const Sidewinder = @import("sidewinder.zig").Sidewinder;
pub const AldousBroder = @import("aldous_broder.zig").AldousBroder;
pub const Wilson = @import("wilson.zig").Wilson;
pub const Fast = @import("fast.zig").Fast;
pub const HuntAndKill = @import("hunt_and_kill.zig").HuntAndKill;
pub const RecursiveBacktracker = @import("recursive_backtracker.zig").RecursiveBacktracker;

pub const Qanvas = @import("qanvas.zig").Qanvas;

const Error = error{
    NoSuchMaze,
};

pub fn onByName(comptime GridType: type, name: []const u8, grid: *GridType) !void {
    const eq = @import("std").mem.startsWith;

    switch (GridType) {
        Grid => {
            if (eq(u8, name, "None")) return;
            if (eq(u8, name, "AldousBroder")) return try AldousBroder.on(grid);
            if (eq(u8, name, "Sidewinder")) return try Sidewinder.on(grid);
            if (eq(u8, name, "BinaryTree")) return try BinaryTree.on(grid);
            if (eq(u8, name, "Wilson")) return try Wilson.on(grid);
            if (eq(u8, name, "Fast")) return try Fast.on(grid);
            if (eq(u8, name, "HuntAndKill")) return try HuntAndKill.on(grid);
            if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);
        },
        HexGrid => {
            if (eq(u8, name, "None")) return;
            if (eq(u8, name, "AldousBroder")) return try AldousBroder.on(grid);
            if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);
        },
        TriGrid => {
            if (eq(u8, name, "None")) return;
            if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);
        },
        UpsilonGrid => {
            if (eq(u8, name, "None")) return;
            if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);
        },
        else => return Error.NoSuchMaze,
    }
}

pub fn makeString(comptime GridT: type, grid: *GridT) ![]u8 {
    switch (GridT) {
        Grid => return try grid.makeString(),
        HexGrid => return try @import("hex_grid.zig").makeString(grid),
        else => return Error.NoSuchMaze,
    }
}

pub fn makeQanvas(grid: anytype, walls: bool, scale: usize) !Qanvas {
    switch (@TypeOf(grid)) {
        Grid => return try grid.makeQanvas(walls, scale),
        HexGrid => return try @import("hex_grid.zig").makeQanvas(grid, walls, scale),
        TriGrid => return try @import("tri_grid.zig").makeQanvas(grid, walls, scale),
        UpsilonGrid => return try @import("upsilon_grid.zig").makeQanvas(grid, walls, scale),
        else => return Error.NoSuchMaze,
    }
}

test "Test mazes" {
    // grids
    _ = @import("grid.zig");
    _ = @import("hex_grid.zig");
    _ = @import("tri_grid.zig");
    _ = @import("upsilon_grid.zig");

    // algorithms
    _ = @import("binary_tree.zig");
    _ = @import("sidewinder.zig");
    _ = @import("aldous_broder.zig");
    _ = @import("wilson.zig");
    _ = @import("fast.zig");
    _ = @import("hunt_and_kill.zig");
    _ = @import("recursive_backtracker.zig");
}
