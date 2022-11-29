const std = @import("std");

pub fn State(comptime GridT: type) type {
    return struct {
        const CellSetInfo = struct {
            cell: ?*GridT.CellT = null,
            set: ?u32 = null,
        };

        next_set: u32,
        cell_setinfo_buf: []CellSetInfo,
        alctr: std.mem.Allocator,

        pub fn init(alctr: std.mem.Allocator, row_width: usize, starting_set: u32) !This {
            var s = This{
                .next_set = starting_set,
                .alctr = alctr,
                .cell_setinfo_buf = try alctr.alloc(CellSetInfo, row_width),
            };

            for (s.cell_setinfo_buf) |*info| {
                info.* = .{ .cell = null, .set = null };
            }

            return s;
        }

        pub fn deinit(self: *This) void {
            self.alctr.free(self.cell_setinfo_buf);
        }

        fn getSetInfoOfCell(self: *This, cell: *GridT.CellT) *CellSetInfo {
            return &self.cell_setinfo_buf[cell.y()];
        }

        /// Caller is responsible for freeing returned slice
        pub fn getCellsOfSet(self: *This, set: u32) ![]*GridT.CellT {
            var result = std.ArrayList(*GridT.CellT).init(self.alctr);

            for (self.cell_setinfo_buf) |info| {
                if (info.cell) |cell| {
                    if (info.set.? == set)
                        try result.append(cell);
                }
            }

            return result.toOwnedSlice();
        }

        pub fn record(self: *This, set: u32, cell: *GridT.CellT) void {
            self.cell_setinfo_buf[cell.y()] = .{ .cell = cell, .set = set };
        }

        pub fn getSetOfCell(self: *This, cell: *GridT.CellT) u32 {
            var info = self.getSetInfoOfCell(cell);

            if (info.cell == null) {
                // modifies info
                self.record(self.next_set, cell);
                self.next_set += 1;
            }

            return info.set.?;
        }

        pub fn merge(self: *This, winner: u32, loser: u32) !void {
            var loser_cells = try self.getCellsOfSet(loser);
            defer self.alctr.free(loser_cells);

            for (loser_cells) |lcell| {
                self.record(winner, lcell);
            }
        }

        pub fn nextRow(self: *This) !This {
            return try This.init(self.alctr, self.cell_setinfo_buf.len, self.next_set);
        }

        const SortedSetIterator = struct {
            buf: []*CellSetInfo,
            alctr: std.mem.Allocator,
            i_value: ?u32,
            i: usize,

            pub fn init(alctr: std.mem.Allocator, cells: []CellSetInfo) !@This() {
                var sorted = try alctr.alloc(*CellSetInfo, cells.len);
                for (cells) |*cell, i| {
                    sorted[i] = cell;
                }

                const lt = struct {
                    fn lt(_: void, left: *const CellSetInfo, right: *const CellSetInfo) bool {
                        // null is greater than non null here to pack nulls onto the
                        // end of the list
                        if (left.set == null) return false;
                        if (right.set == null) return true;
                        return left.set.? < right.set.?;
                    }
                }.lt;

                std.sort.sort(*CellSetInfo, sorted, {}, lt);

                return .{ .buf = sorted, .alctr = alctr, .i = 0, .i_value = sorted[0].set };
            }

            pub fn deinit(self: *@This()) void {
                self.alctr.free(self.buf);
            }

            pub fn next(self: *@This()) ?[]*CellSetInfo {
                if (self.i_value) |val| {
                    const start = self.i;
                    while (self.i < self.buf.len and self.buf[self.i].set != null and self.buf[self.i].set.? == val)
                        self.i += 1;

                    if (self.i == self.buf.len) {
                        self.i_value = null;
                    } else {
                        self.i_value = self.buf[self.i].set;
                    }

                    return self.buf[start..self.i];
                } else {
                    return null;
                }
            }
        };

        /// Caller is responsible for calling .deinit on returned iterator
        pub fn sortedSets(self: *This) !SortedSetIterator {
            return try SortedSetIterator.init(self.alctr, self.cell_setinfo_buf);
        }

        const This = @This();
    };
}

pub const Ellers = struct {};

const SquareGrid = @import("square_grid.zig").SquareGrid;

test "state: init/deinit" {
    var st = try State(SquareGrid).init(std.testing.allocator, 16, 0);
    defer st.deinit();
}

test "state: getSetOfCell assigns default value if one isn't present" {
    var g = try SquareGrid.init(std.testing.allocator, 0, 8, 8);
    defer g.deinit();

    var st = try State(SquareGrid).init(g.alctr, g.width, 0);
    defer st.deinit();

    var sets: [4]u32 = undefined;

    var set_a = st.getSetOfCell(g.at(0, 0).?);

    sets[0] = st.getSetOfCell(g.at(0, 0).?);
    sets[1] = st.getSetOfCell(g.at(0, 1).?);
    sets[2] = st.getSetOfCell(g.at(0, 2).?);
    sets[3] = st.getSetOfCell(g.at(0, 3).?);

    try std.testing.expect(sets[0] == set_a);
    try std.testing.expect(sets[1] != set_a);
    try std.testing.expect(sets[2] != set_a);
    try std.testing.expect(sets[3] != set_a);

    {
        var i: usize = 0;
        while (i < sets.len) : (i += 1) {
            var j: usize = i + 1;
            while (j < sets.len) : (j += 1) {
                errdefer std.debug.print("failing values: {} {} ({any})\n", .{ i, j, sets });
                try std.testing.expect(sets[i] != sets[j]);
            }
        }
    }
}

test "state: getCellsOfSet" {
    var alctr = std.testing.allocator;
    var grid = try SquareGrid.init(alctr, 0, 8, 8);
    defer grid.deinit();

    var st = try State(SquareGrid).init(alctr, grid.width, 0);
    defer st.deinit();

    st.record(0, grid.at(0, 0).?);
    st.record(0, grid.at(0, 1).?);
    st.record(0, grid.at(0, 2).?);
    st.record(1, grid.at(0, 3).?);
    st.record(1, grid.at(0, 4).?);
    st.record(1, grid.at(0, 5).?);
    st.record(2, grid.at(0, 6).?);
    st.record(3, grid.at(0, 7).?);

    {
        var set_zero = try st.getCellsOfSet(0);
        defer alctr.free(set_zero);

        try std.testing.expect(set_zero.len == 3);
        try std.testing.expect(set_zero[0] == grid.at(0, 0).?);
        try std.testing.expect(set_zero[1] == grid.at(0, 1).?);
        try std.testing.expect(set_zero[2] == grid.at(0, 2).?);
    }
    {
        var set_one = try st.getCellsOfSet(1);
        defer alctr.free(set_one);

        try std.testing.expect(set_one.len == 3);
        try std.testing.expect(set_one[0] == grid.at(0, 3).?);
        try std.testing.expect(set_one[1] == grid.at(0, 4).?);
        try std.testing.expect(set_one[2] == grid.at(0, 5).?);
    }
    {
        var set_two = try st.getCellsOfSet(2);
        defer alctr.free(set_two);

        try std.testing.expect(set_two.len == 1);
        try std.testing.expect(set_two[0] == grid.at(0, 6).?);
    }
    {
        var set_three = try st.getCellsOfSet(3);
        defer alctr.free(set_three);

        try std.testing.expect(set_three.len == 1);
        try std.testing.expect(set_three[0] == grid.at(0, 7).?);
    }
    {
        var set_four = try st.getCellsOfSet(4);
        defer alctr.free(set_four);

        try std.testing.expect(set_four.len == 0);
    }
}

test "state: merge" {
    var alctr = std.testing.allocator;
    var grid = try SquareGrid.init(alctr, 0, 8, 8);
    defer grid.deinit();

    var st = try State(SquareGrid).init(alctr, grid.width, 0);
    defer st.deinit();

    {
        var sets: [4]u32 = undefined;

        sets[0] = st.getSetOfCell(grid.at(0, 0).?);
        sets[1] = st.getSetOfCell(grid.at(0, 1).?);
        sets[2] = st.getSetOfCell(grid.at(0, 2).?);
        sets[3] = st.getSetOfCell(grid.at(0, 3).?);

        {
            var i: usize = 0;
            while (i < sets.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < sets.len) : (j += 1) {
                    errdefer std.debug.print("failing indices: {} {} (in {any})\n", .{ i, j, sets });
                    try std.testing.expect(sets[i] != sets[j]);
                }
            }
        }

        try st.merge(sets[0], sets[1]);
        sets[1] = st.getSetOfCell(grid.at(0, 1).?);

        try st.merge(sets[1], sets[2]);
        sets[2] = st.getSetOfCell(grid.at(0, 2).?);

        try st.merge(sets[2], sets[3]);
        sets[3] = st.getSetOfCell(grid.at(0, 3).?);

        {
            var i: usize = 0;
            while (i < sets.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < sets.len) : (j += 1) {
                    errdefer std.debug.print("failing indices: {} {} (in {any})\n", .{ i, j, sets });
                    try std.testing.expect(sets[i] == sets[j]);
                }
            }
        }
    }
}

test "state: nextRow" {
    var alctr = std.testing.allocator;
    var grid = try SquareGrid.init(alctr, 0, 8, 8);
    defer grid.deinit();

    var st = try State(SquareGrid).init(alctr, grid.width, 0);
    defer st.deinit();

    // internally generates 3 new sets
    const first = st.getSetOfCell(grid.at(0, 0).?);
    _ = st.getSetOfCell(grid.at(0, 1).?);
    _ = st.getSetOfCell(grid.at(0, 2).?);

    var nxt = try st.nextRow();
    defer nxt.deinit();

    try std.testing.expect(st.next_set == nxt.next_set);

    // only y coordinate matters in the set generation
    const second = nxt.getSetOfCell(grid.at(0, 0).?);

    try std.testing.expect(first != second);

    const third = st.getSetOfCell(grid.at(0, 3).?);

    try std.testing.expect(second == third);
}

test "state: sortedSets" {
    var alctr = std.testing.allocator;
    var grid = try SquareGrid.init(alctr, 0, 16, 8);
    defer grid.deinit();

    var st = try State(SquareGrid).init(alctr, grid.width, 0);
    defer st.deinit();

    st.record(0, grid.at(0, 5).?);
    st.record(0, grid.at(0, 4).?);
    st.record(0, grid.at(0, 3).?);
    st.record(1, grid.at(0, 2).?);
    st.record(1, grid.at(0, 1).?);
    st.record(1, grid.at(0, 0).?);
    st.record(2, grid.at(0, 6).?);
    st.record(3, grid.at(0, 7).?);

    var sorted = try st.sortedSets();
    defer sorted.deinit();

    const block_one = [_]u32{ 0, 0, 0 };
    const block_two = [_]u32{ 1, 1, 1 };
    const block_three = [_]u32{2};
    const block_four = [_]u32{3};

    if (sorted.next()) |block| {
        try std.testing.expect(block.len == block_one.len);
        for (block) |info, i| {
            try std.testing.expect(info.set.? == block_one[i]);
        }
    } else {
        try std.testing.expect(false);
    }

    if (sorted.next()) |block| {
        try std.testing.expect(block.len == block_two.len);
        for (block) |info, i| {
            try std.testing.expect(info.set.? == block_two[i]);
        }
    } else {
        try std.testing.expect(false);
    }

    if (sorted.next()) |block| {
        try std.testing.expect(block.len == block_three.len);
        for (block) |info, i| {
            try std.testing.expect(info.set.? == block_three[i]);
        }
    } else {
        try std.testing.expect(false);
    }

    if (sorted.next()) |block| {
        try std.testing.expect(block.len == block_four.len);
        for (block) |info, i| {
            try std.testing.expect(info.set.? == block_four[i]);
        }
    } else {
        try std.testing.expect(false);
    }

    try std.testing.expect(sorted.next() == null);
}