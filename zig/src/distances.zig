const std = @import("std");

pub fn Distances(comptime GridT: type) type {
    return struct {
        grid: *GridT,
        root: *GridT.CellT,
        alloc: std.mem.Allocator,

        // this is used as a hash table from cell to distance (or weight) value. use the
        // get() and set() methods to map into it.
        dists: []?u32 = undefined,

        pub fn init(alloc: std.mem.Allocator, grid: *GridT, root: *GridT.CellT) !Self {
            var d: Distances(GridT) = .{
                .grid = grid,
                .root = root,
                .alloc = alloc,
                .dists = try alloc.alloc(?u32, grid.size() * 2),
            };

            for (d.dists) |*dist| dist.* = null;

            return d;
        }

        pub fn from(grid: *GridT, cell: *GridT.CellT) !Distances(GridT) {
            var dists = try Distances(GridT).init(grid.alctr, grid, cell);
            try dists.put(cell, cell.weight());

            const comp = struct {
                fn f(_: void, a: *GridT.CellT, b: *GridT.CellT) std.math.Order {
                    if (a.weight() < b.weight()) return .lt;
                    if (a.weight() == b.weight()) return .eq;
                    if (a.weight() > b.weight()) return .gt;
                    unreachable;
                }
            }.f;

            var frontier = std.PriorityQueue(*GridT.CellT, void, comp).init(dists.alloc, {});
            defer frontier.deinit();

            try frontier.add(cell);

            while (frontier.count() > 0) {
                var cellptr = frontier.remove();

                for (std.mem.sliceTo(&cellptr.links(), null)) |c| {
                    const total_weight = dists.get(cellptr).? + c.?.weight();
                    if (dists.get(c.?) == null or total_weight < dists.get(c.?).?) {
                        try frontier.add(c.?);
                        try dists.put(c.?, total_weight);
                    }
                }
            }

            return dists;
        }

        pub fn deinit(this: *Self) void {
            this.alloc.free(this.dists);
        }

        fn key(this: Self, cell: *GridT.CellT) usize {
            const k = switch (@TypeOf(cell.*)) {
                @import("weave_grid.zig").WeaveCell => switch (cell.*) {
                    .over => this.grid.width * cell.y() + cell.x(),
                    .under => this.grid.size() + (this.grid.width * cell.y() + cell.x()),
                },
                else => this.grid.width * cell.y() + cell.x(),
            };
            return k;
        }

        pub fn get(this: Self, cell: *GridT.CellT) ?u32 {
            return this.dists[this.key(cell)];
        }

        pub fn put(this: *Self, cell: *GridT.CellT, dist: u32) !void {
            this.dists[this.key(cell)] = dist;
        }

        pub fn pathTo(this: Self, goal: *GridT.CellT) !Distances(GridT) {
            var current = goal;

            var breadcrumbs = try Distances(GridT).init(this.alloc, this.grid, this.root);
            try breadcrumbs.put(current, this.get(current).?);

            while (current != this.root) {
                for (current.links()) |mnei| {
                    var neighbor = mnei.?;
                    if (this.get(neighbor).? < this.get(current).?) {
                        try breadcrumbs.put(neighbor, this.get(neighbor).?);
                        current = neighbor;
                        break;
                    }
                }
            }

            return breadcrumbs;
        }

        pub fn max(this: Self) struct { cell: *GridT.CellT, distance: u32 } {
            var dist: u32 = 0;
            var cell = this.root;

            for (this.dists) |mdist, i| {
                if (mdist) |entry| {
                    if (entry > dist) {
                        dist = entry;
                        const x = @intCast(u32, (i % this.grid.width) % this.grid.width);
                        const y = @intCast(u32, @divTrunc(i, this.grid.width) % this.grid.width);
                        cell = this.grid.at(x, y).?;
                    }
                }
            }

            return .{ .cell = cell, .distance = if (dist != 0) dist else std.math.maxInt(u32) };
        }

        const Self = @This();
    };
}
