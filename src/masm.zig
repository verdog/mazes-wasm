const maze = @import("mazes.zig");

const std = @import("std");
const Options = @import("Options.zig");

var current_opts = Options{
    .braid = 0,
    .scale = 32,
    .width = 24,
    .height = 24,
    .qoi_walls = false,
    .inset = 0.05,
};

var alctr = std.heap.page_allocator;

extern fn consoleDebug(ptr: [*]const u8, len: u32) void;

extern fn ctxSetSize(w: u32, h: u32) void;

extern fn ctxFillAll() void;
extern fn ctxFillStyle(ptr: [*]const u8, len: u32) void;
extern fn ctxFillRect(x: u32, y: u32, width: u32, height: u32) void;

extern fn ctxStrokeStyle(ptr: [*]const u8, len: u32) void;
extern fn ctxLine(x1: u32, x2: u32, y1: u32, y2: u32) void;

// settings:

export fn getWalls() bool {
    return current_opts.qoi_walls;
}

export fn setWalls(checked: bool) void {
    current_opts.qoi_walls = checked;
}

export fn setFillCells(checked: bool) void {
    current_opts.qoi_bg = checked;
}

export fn getFillCells() bool {
    return current_opts.qoi_bg;
}

export fn getSeed() u32 {
    return @truncate(current_opts.seed);
}

export fn setSeed(seed: u32) void {
    current_opts.seed = seed;
}

export fn getWidth() u32 {
    return current_opts.width;
}

export fn setWidth(width: u32) void {
    current_opts.width = width;
}

export fn getHeight() u32 {
    return current_opts.height;
}

export fn setHeight(height: u32) void {
    current_opts.height = height;
}

export fn getScale() u32 {
    return @truncate(current_opts.scale);
}

export fn setScale(scale: u32) void {
    current_opts.scale = scale;
}

export fn getBraid() f32 {
    return @floatCast(current_opts.braid);
}

export fn setBraid(braid: f32) void {
    current_opts.braid = @floatCast(braid);
}

export fn getInset() f32 {
    return @floatCast(current_opts.inset);
}

export fn setInset(inset: f32) void {
    current_opts.inset = @floatCast(inset);
}

// TODO gen type string
// TODO grid (potentially requires porting of other grid draw funcs)

fn jlog(str: []const u8) void {
    consoleDebug(str.ptr, str.len);
}

fn logJLog(comptime _: std.log.Level, comptime _: @TypeOf(.EnumLiteral), comptime s: []const u8, _: anytype) void {
    jlog(s);
}

// overwrite default log function to avoid "freestanding has no io" error
pub const std_options = struct {
    pub const logFn = logJLog;
};

export fn gen() void {
    const Grid = maze.SquareGrid;
    var grid = Grid.init(
        alctr,
        current_opts.seed,
        current_opts.width,
        current_opts.height,
    ) catch unreachable;
    defer grid.deinit();

    std.log.info("Generating...", .{});
    maze.onByName(&current_opts.type, &grid) catch unreachable;

    if (current_opts.braid > 0) {
        std.log.info("Braiding...", .{});
        grid.braid(current_opts.braid) catch unreachable;
    }

    {
        // to preserve colors after changes to braid setting etc
        grid.setSeed(current_opts.seed);

        std.log.info("Calcuating distances...", .{});
        grid.distances = maze.Distances(Grid).from(&grid, grid.pickRandom()) catch unreachable;
    }

    {
        std.log.info("Drawing image... ", .{});
        const Qixel = @import("qanvas.zig").Qixel;
        const qoi = @import("qoi.zig");

        var qanv = struct {
            style_string: [64]u8 = undefined,

            pub fn fill(self: *@This(), color: Qixel(qoi.RGB), x1: u32, x2: u32, y1: u32, y2: u32) void {
                // construct rgb color string
                var fbs = std.io.fixedBufferStream(&self.style_string);
                fbs.writer().print("rgb({},{},{})\x00", .{
                    color.colors.red,
                    color.colors.blue,
                    color.colors.green,
                }) catch unreachable;
                const len = std.mem.indexOfScalar(u8, &self.style_string, 0) orelse self.style_string.len;
                ctxFillStyle(&self.style_string, len);

                ctxFillRect(
                    x1,
                    y1,
                    x2 - x1,
                    y2 - y1,
                );
            }

            pub fn line(self: *@This(), color: Qixel(qoi.RGB), x1: u32, x2: u32, y1: u32, y2: u32) void {
                // construct rgb color string
                var fbs = std.io.fixedBufferStream(&self.style_string);
                fbs.writer().print("rgb({},{},{})\x00", .{
                    color.colors.red,
                    color.colors.blue,
                    color.colors.green,
                }) catch unreachable;
                const len = std.mem.indexOfScalar(u8, &self.style_string, 0) orelse self.style_string.len;
                ctxStrokeStyle(&self.style_string, len);

                ctxLine(x1, x2, y1, y2);
            }

            pub fn clear(self: *@This(), color: Qixel(qoi.RGB)) void {
                // construct rgb color string
                var fbs = std.io.fixedBufferStream(&self.style_string);
                fbs.writer().print("rgb({},{},{})\x00", .{
                    color.colors.red,
                    color.colors.blue,
                    color.colors.green,
                }) catch unreachable;
                const len = std.mem.indexOfScalar(u8, &self.style_string, 0) orelse self.style_string.len;
                ctxFillStyle(&self.style_string, len);

                ctxFillAll();
            }
        }{};

        const cell_size: u32 = @intCast(current_opts.scale);
        const border_size = cell_size / 2;
        ctxSetSize(
            grid.width * cell_size + border_size * 2,
            grid.height * cell_size + border_size * 2,
        );

        // to preserve colors after changes to braid setting etc
        grid.setSeed(current_opts.seed);

        grid.writeCanvasInset(
            current_opts.qoi_walls,
            current_opts.qoi_bg,
            current_opts.scale,
            current_opts.inset,
            &qanv,
        ) catch unreachable;
    }
}
