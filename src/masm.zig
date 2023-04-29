const maze = @import("mazes.zig");

const std = @import("std");
const Options = @import("Options.zig");

var current_opts = Options{};
var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alctr = heap.allocator();

extern fn consoleDebug(ptr: [*]const u8, len: u32) void;

fn jlog(str: []const u8) void {
    consoleDebug(str.ptr, str.len);
}

// overwrite default log function to avoid "freestanding has no io" error
pub const std_options = struct {
    pub const logFn = logJLog;
};

fn logJLog(comptime _: std.log.Level, comptime _: @TypeOf(.EnumLiteral), comptime s: []const u8, _: anytype) void {
    jlog(s);
}

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

    // if (current_opts.braid > 0) {
    //     jlog("Braiding...");
    //     grid.braid(current_opts.braid) catch unreachable;
    // }

    if (current_opts.text) {
        jlog("Generating text... ");
        if (maze.makeString(Grid, &grid)) |txt| {
            defer alctr.free(txt);
            jlog(txt);
        } else |err| switch (err) {
            else => unreachable,
        }
    }

    // {
    //     jlog("Calcuating distances... ");
    //     grid.distances = maze.Distances(Grid).from(&grid, grid.pickRandom()) catch unreachable;
    // }
}
