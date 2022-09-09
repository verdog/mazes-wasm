const std = @import("std");

const grd = @import("grid.zig");
const maze = @import("mazes.zig");
const u = @import("u.zig");

var heap = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = heap.allocator();
const stdout = std.io.getStdOut().writer();

const Options = struct {
    text: bool = true,
    qoi: bool = false,
    qoi_walls: bool = true,
    seed: u64 = 0,
    width: u32 = 8,
    height: u32 = 8,
    @"type": [64]u8 = u.strBuf(64, "AldousBroder"),

    pub fn withRandomSeed() Options {
        return .{
            .seed = @byteSwap(@truncate(u64, @bitCast(u128, std.time.nanoTimestamp()))),
        };
    }
};

fn printOptions(opt: Options) void {
    std.debug.print("With options:\n", .{});
    std.debug.print(
        \\ - text: {}
        \\ - qoi: {}
        \\ - qoi_walls: {}
        \\ - seed: {d}
        \\ - width: {d}
        \\ - height: {d}
        \\ - type: {s}
        \\
    , .{ opt.text, opt.qoi, opt.qoi_walls, opt.seed, opt.width, opt.height, std.mem.sliceTo(&opt.@"type", 0) });
}

pub fn main() !void {
    defer _ = heap.detectLeaks();

    // parse args
    var opts = Options.withRandomSeed();
    for (std.os.argv) |sarg| {
        const eq = std.mem.eql;
        const arg = std.mem.span(sarg);

        // flags
        if (eq(u8, "--text", arg)) {
            opts.text = true;
        } else if (eq(u8, "--notext", arg)) {
            opts.text = false;
        } else if (eq(u8, "--qoi", arg)) {
            opts.qoi = true;
        } else if (eq(u8, "--noqoi", arg)) {
            opts.qoi = false;
        } else if (eq(u8, "--qoi-walls", arg)) {
            opts.qoi_walls = true;
        } else if (eq(u8, "--noqoi-walls", arg)) {
            opts.qoi_walls = false;
        } else {
            // values
            var it = std.mem.split(u8, arg, "=");
            _ = it;

            if (it.next()) |left| {
                if (eq(u8, "--seed", left)) {
                    if (it.next()) |right| {
                        opts.seed = try std.fmt.parseUnsigned(@TypeOf(opts.seed), right, 10);
                    }
                } else if (eq(u8, "--width", left)) {
                    if (it.next()) |right| {
                        opts.width = try std.fmt.parseUnsigned(@TypeOf(opts.width), right, 10);
                    }
                } else if (eq(u8, "--height", left)) {
                    if (it.next()) |right| {
                        opts.height = try std.fmt.parseUnsigned(@TypeOf(opts.height), right, 10);
                    }
                } else if (eq(u8, "--type", left)) {
                    if (it.next()) |right| {
                        for (@typeInfo(maze).Struct.decls) |dec| {
                            if (eq(u8, dec.name, right)) {
                                std.mem.copy(u8, &opts.@"type", right);
                                opts.@"type"[right.len] = 0;
                            }
                        }
                    }
                }
            }
        }
    }

    try run(opts);
}

fn run(opt: Options) !void {
    printOptions(opt);

    var grid = try grd.Grid.init(alloc, opt.seed, opt.width, opt.height);
    defer grid.deinit();

    try maze.onByName(&opt.@"type", &grid);

    if (opt.text) {
        var txt = try grid.makeString();
        defer alloc.free(txt);
        std.debug.print("{s}\n", .{txt});
    }

    grid.distances = try grid.at(@divTrunc(grid.width, 2), @divTrunc(grid.height, 2)).?.distances();

    if (opt.qoi) {
        var encoded = try grid.makeQoi(opt.qoi_walls);
        defer alloc.free(encoded);
        try stdout.print("{s}", .{encoded});
    }
}

test "Run all tests" {
    _ = @import("grid.zig");
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
