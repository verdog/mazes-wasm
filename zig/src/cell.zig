// TODO doc

const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

pub const Unit = u32;

pub const Cell = struct {
    _row: Unit = 0,
    _col: Unit = 0,

    _mem: Allocator,
    _links: std.AutoHashMap(*Cell, void),

    // TODO make these private and move Grid class into this file
    north: ?*Cell = null,
    south: ?*Cell = null,
    east: ?*Cell = null,
    west: ?*Cell = null,

    pub const LinksI = std.AutoHashMap(*Cell, void).KeyIterator;
    pub const NeighborI = struct {
        _i: usize = 0,
        _parent: *Cell,

        fn init(parent: *Cell) NeighborI {
            return NeighborI{
                ._parent = parent,
            };
        }

        pub fn next(self: *NeighborI) ?*Cell {
            if (self._i >= 4) return null;

            if (self._i == 0 and self._parent.north != null) {
                self._i = 1;
                return self._parent.north;
            }
            if (self._i <= 1 and self._parent.south != null) {
                self._i = 2;
                return self._parent.south;
            }
            if (self._i <= 2 and self._parent.east != null) {
                self._i = 3;
                return self._parent.east;
            }
            if (self._i <= 3 and self._parent.west != null) {
                self._i = 4;
                return self._parent.west;
            }

            return null;
        }
    };

    pub fn init(mem: Allocator, row: Unit, col: Unit) Cell {
        return Cell{
            ._row = row,
            ._col = col,
            ._mem = mem,
            ._links = std.AutoHashMap(*Cell, void).init(mem),
        };
    }

    pub fn deinit(self: *Cell) void {
        self._links.deinit();
    }

    // bidirectional link
    // self <---> other
    pub fn bLink(self: *Cell, other: *Cell) !void {
        try self._links.put(other, {});
        try other.mLink(self);
    }

    // monodirectional link
    // self ----> other
    pub fn mLink(self: *Cell, other: *Cell) !void {
        try self._links.put(other, {});
    }

    fn unLink(self: *Cell, other: *Cell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    // monedirectional unlink
    fn mUnLink(self: *Cell, other: *Cell) void {
        // no-ops are fine
        _ = self._links.remove(other);
    }

    pub fn isLinked(self: Cell, other: *Cell) bool {
        return self._links.contains(other);
    }

    pub fn links(self: Cell) Cell.LinksI {
        return self._links.keyIterator();
    }

    pub fn neighbors(self: *Cell) Cell.NeighborI {
        return Cell.NeighborI.init(self);
    }
};

test "Construct and destruct a Cell" {
    var alloc = std.testing.allocator;
    var c = Cell.init(alloc, 0, 0);
    defer c.deinit();
}

test "Cell can link to another Cell" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 0, 0);
    defer b.deinit();

    try a.bLink(&b);

    try expect(a.isLinked(&b) == true);
    try expect(b.isLinked(&a) == true);
}

test "Cell can unlink after linking another Cell" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 0, 0);
    defer b.deinit();

    try a.bLink(&b);

    try expect(a.isLinked(&b) == true);
    try expect(b.isLinked(&a) == true);

    a.unLink(&b);

    try expect(a.isLinked(&b) == false);
    try expect(b.isLinked(&a) == false);
}

test "Cell provides an iterator over its links" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 1, 0);
    defer b.deinit();
    var c = Cell.init(alloc, 2, 0);
    defer c.deinit();
    var d = Cell.init(alloc, 3, 0);
    defer d.deinit();

    try a.bLink(&b);
    try a.bLink(&c);
    try a.bLink(&d);

    {
        var it = a.links();
        var count: u32 = 0;
        while (it.next()) |link| {
            _ = link;
            count += 1;
        }

        try expectEq(@as(@TypeOf(count), 3), count);
    }
}

test "Cell provides a list of its neighbors" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 1, 0);
    defer b.deinit();
    var c = Cell.init(alloc, 2, 0);
    defer c.deinit();

    b.west = &a;
    b.east = &c;

    {
        var it = b.neighbors();
        var count: u32 = 0;
        while (it.next()) |nei| {
            _ = nei;
            count += 1;
        }

        try expectEq(@as(@TypeOf(count), 2), count);
    }
}
