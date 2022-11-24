//! generic growing tree algorithm with swappable selection

const std = @import("std");

pub const GrowingTree = struct {
    pub fn on(grid: anytype) !void {
        // grid should be a pointer
        const algo = genGrowingTree(@TypeOf(grid.*), genPickRandom(@TypeOf(grid.*))){};
        try algo.on(grid);
    }
};

pub const GrowingTreeSpindly = struct {
    pub fn on(grid: anytype) !void {
        // grid should be a pointer
        const algo = genGrowingTree(@TypeOf(grid.*), genPickLast(@TypeOf(grid.*))){};
        try algo.on(grid);
    }
};

pub const GrowingTreeMixed = struct {
    pub fn on(grid: anytype) !void {
        // grid should be a pointer
        const algo = genGrowingTree(@TypeOf(grid.*), genPickMixed(@TypeOf(grid.*))){};
        try algo.on(grid);
    }
};

fn genGrowingTree(comptime GridT: type, comptime pickFn: fn (std.ArrayList(*GridT.CellT)) usize) type {
    return struct {
        pick: @TypeOf(pickFn) = pickFn,

        pub fn on(comptime self: @This(), grid: anytype) !void {
            var active = std.ArrayList(*@TypeOf(grid.*).CellT).init(grid.alctr);
            defer active.deinit();

            try active.append(grid.pickRandom());

            while (active.items.len > 0) {
                const idx = self.pick(active);

                var cell = active.items[idx];
                if (cell.randomNeighborUnlinked()) |nei| {
                    try active.append(nei);
                    try cell.bLink(nei);
                } else {
                    _ = active.orderedRemove(idx);
                }
            }
        }
    };
}

fn genPickLast(comptime GridT: type) fn (std.ArrayList(*GridT.CellT)) usize {
    const gen = struct {
        fn pick(list: std.ArrayList(*GridT.CellT)) usize {
            return list.items.len - 1;
        }
    };

    return gen.pick;
}

fn genPickRandom(comptime GridT: type) fn (std.ArrayList(*GridT.CellT)) usize {
    const gen = struct {
        fn pick(list: std.ArrayList(*GridT.CellT)) usize {
            return list.items[0].prng().random().intRangeLessThan(usize, 0, list.items.len);
        }
    };

    return gen.pick;
}

fn genPickFirst(comptime GridT: type) fn (std.ArrayList(*GridT.CellT)) usize {
    const gen = struct {
        fn pick(list: std.ArrayList(*GridT.CellT)) usize {
            _ = list;
            return 0;
        }
    };

    return gen.pick;
}

fn genPickMixed(comptime GridT: type) fn (std.ArrayList(*GridT.CellT)) usize {
    const gen = struct {
        fn pick(list: std.ArrayList(*GridT.CellT)) usize {
            var random = list.items[0].prng().random();

            if (random.intRangeLessThan(usize, 0, 10) < 8) {
                return list.items.len - 1;
            } else {
                return list.items[0].prng().random().intRangeLessThan(usize, 0, list.items.len);
            }
        }
    };

    return gen.pick;
}

const SquareGrid = @import("square_grid.zig").SquareGrid;

test "end to end: pickLast" {
    var alloc = std.testing.allocator;
    var g = try SquareGrid.init(alloc, 0, 10, 10);
    defer g.deinit();

    try GrowingTreeSpindly.on(&g);

    const s = try g.makeString();
    defer g.alctr.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|   |               |       |           |
        \\+   +   +---+---+   +   +   +---+   +   +
        \\|   |           |   |   |   |       |   |
        \\+   +---+---+   +   +   +   +   +---+---+
        \\|           |   |   |   |   |           |
        \\+   +   +---+   +   +   +   +   +---+   +
        \\|   |   |   |   |   |   |   |   |       |
        \\+---+   +   +   +   +   +   +   +   +   +
        \\|       |       |       |   |   |   |   |
        \\+   +---+---+---+---+---+   +---+   +   +
        \\|                   |   |           |   |
        \\+   +---+   +---+   +   +---+---+---+   +
        \\|       |   |                       |   |
        \\+---+---+   +---+---+---+---+---+   +   +
        \\|           |           |           |   |
        \\+   +---+   +   +---+   +   +---+---+   +
        \\|   |       |   |   |   |           |   |
        \\+   +---+---+   +   +   +---+---+---+   +
        \\|                   |                   |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "end to end: pickRandom" {
    var alloc = std.testing.allocator;
    var g = try SquareGrid.init(alloc, 0, 10, 10);
    defer g.deinit();

    const algo = genGrowingTree(SquareGrid, genPickRandom(SquareGrid)){};
    try algo.on(&g);

    const s = try g.makeString();
    defer g.alctr.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|   |               |   |   |       |   |
        \\+   +---+   +---+---+   +   +   +---+   +
        \\|   |   |   |                   |   |   |
        \\+   +   +   +   +---+---+---+   +   +   +
        \\|   |   |               |   |   |       |
        \\+   +   +   +---+---+---+   +---+   +---+
        \\|                       |               |
        \\+---+   +   +---+---+   +   +---+---+   +
        \\|       |           |       |       |   |
        \\+   +   +   +   +---+---+---+   +---+   +
        \\|   |   |   |           |           |   |
        \\+   +---+   +   +---+   +   +---+---+---+
        \\|       |   |       |                   |
        \\+---+---+   +---+   +   +   +---+---+---+
        \\|               |   |   |               |
        \\+   +---+---+   +---+   +   +---+   +---+
        \\|   |               |   |       |   |   |
        \\+   +   +---+   +---+   +---+   +---+   +
        \\|   |   |           |       |           |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "end to end: pickFirst" {
    var alloc = std.testing.allocator;
    var g = try SquareGrid.init(alloc, 0, 10, 10);
    defer g.deinit();

    const algo = genGrowingTree(SquareGrid, genPickFirst(SquareGrid)){};
    try algo.on(&g);

    const s = try g.makeString();
    defer g.alctr.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|           |                           |
        \\+---+---+   +   +---+---+---+---+---+---+
        \\|           |                           |
        \\+---+---+   +   +---+---+---+---+---+---+
        \\|           |                           |
        \\+---+---+   +   +---+---+---+---+---+---+
        \\|                                       |
        \\+---+---+   +---+---+---+---+---+---+---+
        \\|                                       |
        \\+---+---+   +---+---+---+---+---+---+---+
        \\|                                       |
        \\+---+---+   +---+---+---+---+---+---+---+
        \\|                                       |
        \\+---+---+   +   +   +---+---+---+---+---+
        \\|           |   |                       |
        \\+   +   +   +   +   +   +   +   +   +   +
        \\|   |   |   |   |   |   |   |   |   |   |
        \\+   +   +   +   +   +   +   +   +   +   +
        \\|   |   |   |   |   |   |   |   |   |   |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
