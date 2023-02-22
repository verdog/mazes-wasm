const std = @import("std");

pub const RecursiveDivision = struct {
    pub fn on(grid: anytype) !void {
        // grid should be a pointer

        // clear out grid
        for (grid.cells_buf) |*cell| {
            for (std.mem.sliceTo(&cell.neighbors(), null)) |neip| {
                try cell.mLink(neip.?);
            }
        }

        // go
        divide(grid, 0, 0, grid.width, grid.height);
    }

    fn divide(grid: anytype, x: u32, y: u32, width: u32, height: u32) void {
        const pick = grid.prng.random().intRangeLessThan(u8, 0, 4) == 0;
        const room_size = @divTrunc(std.math.min(grid.width, grid.height), 4) + 1;
        if ((height < room_size and width < room_size and pick) or (width <= 1 or height <= 1)) return;

        if (height > width)
            divideHorizontally(grid, x, y, width, height)
        else
            divideVertically(grid, x, y, width, height);
    }

    fn divideHorizontally(grid: anytype, x: u32, y: u32, width: u32, height: u32) void {
        // boundary is on the south of chosen row
        const boundary = grid.prng.random().intRangeLessThan(u32, 0, height - 1);
        const passage = grid.prng.random().intRangeLessThan(u32, 0, width);

        {
            var x_offset: u32 = 0;
            while (x_offset < width) : (x_offset += 1) {
                if (x_offset == passage) continue;

                var top = grid.at(x + x_offset, y + boundary).?;
                var bottom = top.south().?;
                top.unLink(bottom);
            }
        }

        divide(grid, x, y, width, boundary + 1);
        divide(grid, x, y + boundary + 1, width, height - boundary - 1);
    }

    fn divideVertically(grid: anytype, x: u32, y: u32, width: u32, height: u32) void {
        // boundary is on the east of chosen row
        const boundary = grid.prng.random().intRangeLessThan(u32, 0, width - 1);
        const passage = grid.prng.random().intRangeLessThan(u32, 0, height);

        {
            var y_offset: u32 = 0;
            while (y_offset < height) : (y_offset += 1) {
                if (y_offset == passage) continue;

                var left = grid.at(x + boundary, y + y_offset).?;
                var right = left.east().?;
                left.unLink(right);
            }
        }

        divide(grid, x, y, boundary + 1, height);
        divide(grid, x + boundary + 1, y, width - boundary - 1, height);
    }
};

const SquareGrid = @import("square_grid.zig").SquareGrid;

test "end to end" {
    var alloc = std.testing.allocator;
    var g = try SquareGrid.init(std.testing.allocator, 0, 8, 8);
    defer g.deinit();

    try RecursiveDivision.on(&g);

    const s = try g.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+
        \\|                       |   |   |
        \\+---+   +   +   +   +   +   +   +
        \\|       |   |   |   |   |       |
        \\+---+   +---+---+---+   +   +---+
        \\|       |       |       |       |
        \\+   +   +   +   +   +   +   +---+
        \\|   |   |   |   |       |       |
        \\+---+   +   +   +   +---+---+   +
        \\|       |   |           |   |   |
        \\+---+---+   +---+---+---+   +   +
        \\|       |   |       |   |       |
        \\+   +   +   +   +   +   +---+   +
        \\|   |       |   |       |   |   |
        \\+---+   +   +---+   +   +   +   +
        \\|       |           |           |
        \\+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
