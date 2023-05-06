const maze = @import("mazes.zig");

const std = @import("std");
const Options = @import("Options.zig");

var current_opts = Options{
    .braid = 0.1,
    .scale = 32 / 4,
    .width = 24 * 4,
    .height = 24 * 4,
    .qoi_walls = false,
};

var alctr = std.heap.page_allocator;

extern fn consoleDebug(ptr: [*]const u8, len: u32) void;

extern fn ctxSetSize(w: u32, h: u32) void;

extern fn ctxFillAll() void;
extern fn ctxFillStyle(ptr: [*]const u8, len: u32) void;
extern fn ctxFillRect(x: u32, y: u32, width: u32, height: u32) void;

extern fn ctxStrokeStyle(ptr: [*]const u8, len: u32) void;
extern fn ctxLine(x1: u32, x2: u32, y1: u32, y2: u32) void;

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

    jlog("Generating...");
    maze.onByName(&current_opts.type, &grid) catch unreachable;

    if (current_opts.braid > 0) {
        jlog("Braiding...");
        grid.braid(current_opts.braid) catch unreachable;
    }

    {
        jlog("Calcuating distances... ");
        grid.distances = maze.Distances(Grid).from(&grid, grid.pickRandom()) catch unreachable;
    }

    {
        jlog("Drawing image... ");
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

        const cell_size = @intCast(u32, current_opts.scale);
        const border_size = cell_size / 2;
        ctxSetSize(
            grid.width * cell_size + border_size * 2,
            grid.height * cell_size + border_size * 2,
        );
        grid.writeCanvasInset(
            current_opts.qoi_walls,
            current_opts.scale,
            current_opts.inset,
            &qanv,
        ) catch unreachable;
    }

    current_opts.seed +%= 1;
}

export fn setSeed(seed: u32) void {
    current_opts.seed = seed;
}
