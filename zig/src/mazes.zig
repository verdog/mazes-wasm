pub const Distances = @import("distances.zig").Distances;

pub const BinaryTree = @import("binary_tree.zig").BinaryTree;
pub const Sidewinder = @import("sidewinder.zig").Sidewinder;
pub const AldousBroder = @import("aldous_broder.zig").AldousBroder;
pub const Wilson = @import("wilson.zig").Wilson;
pub const Fast = @import("fast.zig").Fast;
pub const HuntAndKill = @import("hunt_and_kill.zig").HuntAndKill;
pub const RecursiveBacktracker = @import("recursive_backtracker.zig").RecursiveBacktracker;

pub const Qanvas = @import("qanvas.zig").Qanvas;

pub const SquareGrid = @import("square_grid.zig").SquareGrid;
pub const HexGrid = @import("hex_grid.zig").HexGrid;
pub const TriGrid = @import("tri_grid.zig").TriGrid;
pub const UpsilonGrid = @import("upsilon_grid.zig").UpsilonGrid;
pub const WeaveGrid = @import("weave_grid.zig").WeaveGrid;

pub const AllMazes = [_]type{ SquareGrid, HexGrid, TriGrid, UpsilonGrid, WeaveGrid };

const std = @import("std");

pub const Error = error{
    NoSuchMaze,
};

pub fn onByName(name: []const u8, grid: anytype) !void {
    const eq = @import("std").mem.startsWith;

    if (@TypeOf(grid) == *SquareGrid) {
        if (eq(u8, name, "Sidewinder")) return try Sidewinder.on(grid);
        if (eq(u8, name, "BinaryTree")) return try BinaryTree.on(grid);
    }

    if (eq(u8, name, "None")) return;
    if (eq(u8, name, "AldousBroder")) return try AldousBroder.on(grid);
    if (eq(u8, name, "Wilson")) return try Wilson.on(grid);
    if (eq(u8, name, "Fast")) return try Fast.on(grid);
    if (eq(u8, name, "HuntAndKill")) return try HuntAndKill.on(grid);
    if (eq(u8, name, "RecursiveBacktracker")) return try RecursiveBacktracker.on(grid);

    return Error.NoSuchMaze;
}

// TODO fix these up
pub fn makeString(comptime GridT: type, grid: *GridT) anyerror![]u8 {
    switch (GridT) {
        SquareGrid => return try grid.makeString(),
        HexGrid => return try @import("hex_grid.zig").makeString(grid),
        else => return Error.NoSuchMaze,
    }
}

// TODO fix these up
pub fn makeQanvas(grid: anytype, walls: bool, scale: usize, inset: f64) !Qanvas {
    switch (@TypeOf(grid)) {
        SquareGrid => return try grid.makeQanvas(walls, scale, inset),
        HexGrid => return try @import("hex_grid.zig").makeQanvas(grid, walls, scale),
        TriGrid => return try @import("tri_grid.zig").makeQanvas(grid, walls, scale),
        UpsilonGrid => return try @import("upsilon_grid.zig").makeQanvas(grid, walls, scale),
        WeaveGrid => return try @import("weave_grid.zig").makeQanvas(grid, walls, scale, inset),
        else => return Error.NoSuchMaze,
    }
}

test "Test mazes" {
    // grids
    _ = @import("square_grid.zig");
    _ = @import("hex_grid.zig");
    _ = @import("tri_grid.zig");
    _ = @import("upsilon_grid.zig");
    _ = @import("weave_grid.zig");

    _ = @import("distances.zig");

    // algorithms
    _ = @import("binary_tree.zig");
    _ = @import("sidewinder.zig");
    _ = @import("aldous_broder.zig");
    _ = @import("wilson.zig");
    _ = @import("fast.zig");
    _ = @import("hunt_and_kill.zig");
    _ = @import("recursive_backtracker.zig");
}

fn test_getGrid(comptime GridT: type) !GridT {
    const alctr = std.testing.allocator;
    var g = try GridT.init(alctr, 0, 4, 4);
    return g;
}

fn test_getBigGrid(comptime GridT: type) !GridT {
    const alctr = std.testing.allocator;
    var g = try GridT.init(alctr, 0, 1024, 1024);
    return g;
}

test "grid api: create/destroy" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "grid api: size" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            {
                var g = try test_getGrid(GridT);
                defer g.deinit();
                try std.testing.expect(g.size() == 16);
            }
            {
                var g = try test_getBigGrid(GridT);
                defer g.deinit();
                try std.testing.expect(g.size() == 1024 * 1024);
            }
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "grid api: at" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();

            try std.testing.expect(g.at(0, 0) != null);
            try std.testing.expect(g.at(1, 1) != null);
            try std.testing.expect(g.at(2, 2) != null);
            try std.testing.expect(g.at(3, 3) != null);
            try std.testing.expect(g.at(0, 4) == null);
            try std.testing.expect(g.at(4, 0) == null);
            try std.testing.expect(g.at(4, 4) == null);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "grid api: pickRandom" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();

            var i: usize = 0;
            while (i < 1000) : (i += 1) {
                try std.testing.expect(g.pickRandom().x() < 4);
                try std.testing.expect(g.pickRandom().y() < 4);
            }
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "grid api: cells don't blow up when making random choices" {
    // this test was born out of incorrectly handling the grid's prng member.
    // it used to fail.

    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var alloc = std.testing.allocator;
            // note that seed 1 makes the last check succeed
            var g = try GridT.init(alloc, 1, 5, 5);
            defer g.deinit();

            var choice = g.prng.random().intRangeLessThan(usize, 0, 10);
            var choice2 = g.prng.random().intRangeLessThan(usize, 0, 10);

            try std.testing.expect(choice < 10);
            try std.testing.expect(choice != choice2);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "grid api: deadends" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            {
                // a dead end is defined as a cell with one link.
                // un-mazified grids should have no dead ends.
                const des = try g.deadends();
                defer g.alctr.free(des);

                try std.testing.expect(des.len == 0);
            }

            {
                // [d d]
                try g.at(0, 1).?.bLink(g.at(1, 1).?);

                const des = try g.deadends();
                defer g.alctr.free(des);

                try std.testing.expect(des.len == 2);
            }

            {
                // [d _ _ d]
                try g.at(1, 1).?.bLink(g.at(2, 1).?);
                try g.at(2, 1).?.bLink(g.at(3, 1).?);

                const des = try g.deadends();
                defer g.alctr.free(des);

                try std.testing.expect(des.len == 2);
            }

            {
                // [d   _ d]
                //   |d|
                try g.at(1, 1).?.bLink(g.at(1, 2).?);

                const des = try g.deadends();
                defer g.alctr.free(des);

                try std.testing.expectEqual(@as(usize, 3), des.len);
            }
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "grid api: braid" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            // braid removes dead ends with a probability between 0 and 1.
            // braiding also prefers linking two dead ends over two random cells.
            // XXX: currently the implementation only iterates over dead ends.

            // [_ _|_ _]
            try g.at(0, 0).?.bLink(g.at(1, 0).?);
            try g.at(2, 0).?.bLink(g.at(3, 0).?);

            {
                // shouldn't change maze
                try g.braid(0);
                const des = try g.deadends();
                defer g.alctr.free(des);
                try std.testing.expectEqual(@as(usize, 4), des.len);
            }

            {
                try g.braid(1);
                const des = try g.deadends();
                defer g.alctr.free(des);
                // the two ends of the tunnel
                try std.testing.expectEqual(@as(usize, 2), des.len);
            }
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: Grid has CellT" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            const CellT = GridT.CellT;
            _ = CellT;
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: construct/destruct" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();

            const CellT = GridT.CellT;

            var c = CellT.init(&g, 0, 0);
            defer c.deinit();
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: bLink" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            const CellT = GridT.CellT;

            var a = CellT.init(&g, 0, 0);
            defer a.deinit();
            var b = CellT.init(&g, 0, 1);
            defer b.deinit();

            try a.bLink(&b);

            try std.testing.expect(a.isLinked(&b) == true);
            try std.testing.expect(b.isLinked(&a) == true);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: unLink" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            const CellT = GridT.CellT;

            var a = CellT.init(&g, 0, 0);
            defer a.deinit();
            var b = CellT.init(&g, 0, 1);
            defer b.deinit();

            try a.bLink(&b);

            try std.testing.expect(a.isLinked(&b) == true);
            try std.testing.expect(b.isLinked(&a) == true);

            a.unLink(&b);

            try std.testing.expect(a.isLinked(&b) == false);
            try std.testing.expect(b.isLinked(&a) == false);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: links" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            // note this arrangement of cells is sensitive because of how trigrid works.
            // depending on its location in the grid, a tricell can't link to either a cell
            // above or a cell below it (the point of the triangle has no linkable edge)
            try g.at(1, 1).?.bLink(g.at(0, 1).?);
            try g.at(1, 1).?.bLink(g.at(2, 1).?);
            try g.at(1, 1).?.bLink(g.at(1, 2).?);

            var count: usize = 0;
            for (g.at(1, 1).?.links()) |mlink| {
                if (mlink != null) count += 1;
            }

            try std.testing.expectEqual(@as(@TypeOf(count), 3), count);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: neighbors" {
    const tst = struct {
        fn countNonNullNeighbors(cell: anytype) u32 {
            var count: u32 = 0;
            for (cell.neighbors()) |mnei| {
                if (mnei != null) count += 1;
            }
            return count;
        }

        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            switch (GridT.CellT) {
                SquareGrid.CellT, WeaveGrid.CellT => try std.testing.expect(countNonNullNeighbors(g.at(1, 1).?) == 4),
                HexGrid.CellT => try std.testing.expect(countNonNullNeighbors(g.at(1, 1).?) == 6),
                TriGrid.CellT => try std.testing.expect(countNonNullNeighbors(g.at(1, 1).?) == 3),
                UpsilonGrid.CellT => {
                    try std.testing.expect(countNonNullNeighbors(g.at(1, 1).?) == 8);
                    try std.testing.expect(countNonNullNeighbors(g.at(2, 1).?) == 4);
                },
                else => return error.UntestedCell,
            }
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: randomLink" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            try std.testing.expect(g.at(0, 0).?.randomLink() == null);

            var first = g.at(0, 0).?;
            var second = g.at(0, 1).?;
            try first.bLink(second);

            try std.testing.expect(first.isLinked(second) == true);
            try std.testing.expect(second.isLinked(first) == true);

            try std.testing.expect(first.randomLink() != null);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: randomNeighbor" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            try std.testing.expect(g.at(0, 0).?.randomNeighbor() != null);
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}

test "cell api: cell has .weight field" {
    const tst = struct {
        fn tst(comptime GridT: type) !void {
            var g = try test_getGrid(GridT);
            defer g.deinit();
            errdefer std.debug.print("failing type: {}\n", .{GridT});

            _ = g.at(0, 0).?.weight();
        }
    }.tst;

    inline for (AllMazes) |t| try tst(t);
}
