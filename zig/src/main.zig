const std = @import("std");
const btin = @import("builtin");
const sdl2 = @import("sdl2");

const maze = @import("mazes.zig");
const qan = @import("qanvas.zig");
const u = @import("u.zig");

const stdout = std.io.getStdOut().writer();

const Options = struct {
    text: bool = true,
    qoi: bool = false,
    qoi_walls: bool = true,
    braid: f64 = 0,
    seed: u64 = 0,
    width: u32 = 8,
    height: u32 = 8,
    scale: usize = 8,
    inset: f64 = 0,
    @"type": [64]u8 = u.strBuf(64, "RecursiveBacktracker"),
    viz: Vizualization = .heat,
    grid: Grid = .square,

    const Vizualization = enum {
        heat,
        path,
    };

    const Grid = enum {
        square,
        hex,
        tri,
        upsilon,
        weave,
    };

    pub fn parse(opts: *Options, argv: anytype) !void {
        for (argv) |sarg| {
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
                    } else if (eq(u8, "--scale", left)) {
                        if (it.next()) |right| {
                            opts.scale = try std.fmt.parseUnsigned(@TypeOf(opts.scale), right, 10);
                        }
                    } else if (eq(u8, "--inset", left)) {
                        if (it.next()) |right| {
                            opts.inset = try std.fmt.parseFloat(@TypeOf(opts.inset), right);
                        }
                    } else if (eq(u8, "--braid", left)) {
                        if (it.next()) |right| {
                            opts.braid = try std.fmt.parseFloat(@TypeOf(opts.braid), right);
                        }
                    } else if (eq(u8, "--type", left)) {
                        if (it.next()) |right| {
                            if (eq(u8, "None", right)) {
                                std.mem.copy(u8, &opts.@"type", right);
                                opts.@"type"[right.len] = 0;
                            } else {
                                for (@typeInfo(maze).Struct.decls) |dec| {
                                    if (eq(u8, dec.name, right)) {
                                        std.mem.copy(u8, &opts.@"type", right);
                                        opts.@"type"[right.len] = 0;
                                    }
                                }
                            }
                        }
                    } else if (eq(u8, "--viz", left)) {
                        if (it.next()) |right| {
                            if (std.meta.stringToEnum(Options.Vizualization, right)) |e| {
                                opts.viz = e;
                            }
                        }
                    } else if (eq(u8, "--grid", left)) {
                        if (it.next()) |right| {
                            if (std.meta.stringToEnum(Options.Grid, right)) |e| {
                                opts.grid = e;
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn newSeed(this: *Options) void {
        this.seed = @byteSwap(@truncate(u64, @bitCast(u128, std.time.nanoTimestamp())));
    }

    pub fn print(opt: Options) void {
        std.debug.print("With options:\n", .{});
        std.debug.print(
            \\ - text: {}
            \\ - qoi: {}
            \\ - qoi_walls: {}
            \\ - braid: {d}
            \\ - seed: {d}
            \\ - width: {d}
            \\ - height: {d}
            \\ - scale: {d}
            \\ - inset: {d}
            \\ - type: {s}
            \\ - viz: {s}
            \\ - grid: {s}
            \\
        , .{
            opt.text,
            opt.qoi,
            opt.qoi_walls,
            opt.braid,
            opt.seed,
            opt.width,
            opt.height,
            opt.scale,
            opt.inset,
            std.mem.sliceTo(&opt.@"type", 0),
            u.eString(Options.Vizualization, opt.viz),
            u.eString(Options.Grid, opt.grid),
        });
    }
};

pub fn main() !void {
    // parse args
    var opts = Options{};
    opts.newSeed();
    try opts.parse(std.os.argv);

    var heap = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer heap.deinit();

    // generate maze bytes
    var maze_qan = try dispatch(opts, heap.allocator());
    defer maze_qan.deinit();

    try sdl2.init(.{
        .video = true,
        .events = true,
    });
    defer sdl2.quit();
    try sdl2.image.init(.{ .png = true });
    defer sdl2.image.quit();

    // create window
    var sdl_window = try sdl2.createWindow(
        "Mazes",
        .{ .centered = {} },
        .{ .centered = {} },
        maze_qan.width,
        maze_qan.height,
        .{ .vis = .shown },
    );
    defer sdl_window.destroy();

    var sdl_renderer = try sdl2.createRenderer(sdl_window, null, .{ .accelerated = true });
    defer sdl_renderer.destroy();

    var sdl_tex = try maze_qan.encodeSdl(sdl_renderer);
    defer sdl_tex.destroy();

    main_loop: while (true) {
        while (sdl2.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :main_loop,
                .mouse_button_up => |mouse| {
                    if (mouse.button == .left) {
                        maze_qan.deinit();
                        heap.deinit();
                        heap = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                        opts.newSeed();
                        maze_qan = try dispatch(opts, heap.allocator());
                        try maze_qan.encodeSdlUpdate(&sdl_tex);
                    }
                },
                .key_up => |key| {
                    // TODO parse commands to change the settings
                    _ = key;
                    try stdout.print("TODO\n", .{});
                },
                else => {},
            }
        }

        try sdl_renderer.copy(sdl_tex, null, null);

        sdl_renderer.present();

        sdl2.delay(7); // ~144hz
    }
}

fn dispatch(opt: Options, alloc: std.mem.Allocator) !qan.Qanvas {
    switch (opt.grid) {
        .square => return try run(maze.SquareGrid, opt, alloc),
        .hex => return try run(maze.HexGrid, opt, alloc),
        .tri => return try run(maze.TriGrid, opt, alloc),
        .upsilon => return try run(maze.UpsilonGrid, opt, alloc),
        .weave => return try run(maze.WeaveGrid, opt, alloc),
    }
}

fn run(comptime Grid: type, opt: Options, alloc: std.mem.Allocator) !qan.Qanvas {
    opt.print();

    var grid = try Grid.init(alloc, opt.seed, opt.width, opt.height);
    defer grid.deinit();

    {
        std.debug.print("Generating... ", .{});
        var timer = try std.time.Timer.start();
        try maze.onByName(&opt.@"type", &grid);
        var time = timer.read();
        std.debug.print("Done ({} microseconds)\n", .{time / 1000});
    }

    if (opt.braid > 0) {
        std.debug.print("Braiding...", .{});
        var timer = try std.time.Timer.start();
        try grid.braid(opt.braid);
        var time = timer.read();
        std.debug.print("Done ({} microseconds)\n", .{time / 1000});
    }

    if (opt.text) {
        std.debug.print("Generating text... ", .{});
        var timer = try std.time.Timer.start();
        if (maze.makeString(Grid, &grid)) |txt| {
            var time = timer.read();
            std.debug.print("Done: ({} microseconds)\n", .{time / 1000});
            defer alloc.free(txt);
            std.debug.print("{s}\n", .{txt});
        } else |err| switch (err) {
            maze.Error.NoSuchMaze => std.debug.print("ASCII maze not supported ({})\n", .{err}),
            else => unreachable,
        }
    }

    {
        std.debug.print("Calcuating distances... ", .{});
        var timer = try std.time.Timer.start();
        grid.distances = try maze.Distances(Grid).from(&grid, grid.pickRandom());
        var time = timer.read();
        std.debug.print("Done ({} microseconds)\n", .{time / 1000});
    }

    if (opt.viz == .path) {
        std.debug.print("Finding longest path...", .{});

        // modify distances to be longest path in maze
        var a = grid.distances.?.max().cell;
        var a_dists = try maze.Distances(Grid).from(&grid, a);
        defer a_dists.deinit();

        var b = a_dists.max().cell;
        var a_long = try a_dists.pathTo(b);

        grid.distances.?.deinit();
        grid.distances = a_long;

        std.debug.print("Done\n", .{});
    }

    std.debug.print("Stats:\n", .{});

    {
        var timer = try std.time.Timer.start();
        var deadends = try grid.deadends();
        defer grid.alctr.free(deadends);
        var time = timer.read();
        std.debug.print("- {} dead ends ({d}%) (Calculated in {} microseconds)\n", .{ deadends.len, @intToFloat(f64, deadends.len) / @intToFloat(f64, grid.size()) * 100, time / 1000 });
    }

    if (grid.distances) |dists| {
        var timer = try std.time.Timer.start();
        var max = dists.max();
        var time = timer.read();
        std.debug.print("- {} longest path (Calculated in {} microseconds)\n", .{ max.distance, time / 1000 });
    }

    {
        std.debug.print("Encoding image... ", .{});
        var timer = try std.time.Timer.start();
        var qanv = try maze.makeQanvas(grid, opt.qoi_walls, opt.scale, opt.inset);
        var time = timer.read();
        std.debug.print("Done ({} microseconds)\n", .{time / 1000});

        return qanv;
    }
}

test "Run all tests" {
    _ = @import("mazes.zig");
    _ = @import("qanvas.zig");
    _ = @import("qoi.zig");
}
