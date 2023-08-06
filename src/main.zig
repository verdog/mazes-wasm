const std = @import("std");
const btin = @import("builtin");
const sdl2 = @import("sdl2");

const maze = @import("mazes.zig");
const qan = @import("qanvas.zig");
const u = @import("u.zig");

const stdout = std.io.getStdOut().writer();

const Options = @import("Options.zig");

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

    var command_buffer = [_]u8{0} ** 80;
    var command_cursor: usize = 0;

    main_loop: while (true) {
        while (sdl2.pollEvent()) |ev| {
            var refresh = false;
            switch (ev) {
                .quit => break :main_loop,
                .mouse_button_up => |mouse| {
                    if (mouse.button == .left) {
                        refresh = true;
                    }
                },
                .key_down => |key| {
                    if (key.keycode == .@"return") {
                        try stdout.print("\n", .{});

                        // parse buffer
                        const eq = std.mem.eql;

                        defer {
                            // clear buffer
                            @memset(&command_buffer, 0);
                            command_cursor = 0;
                        }

                        if (eq(u8, "exit", std.mem.sliceTo(&command_buffer, 0))) {
                            break :main_loop;
                        } else if (eq(u8, "", std.mem.sliceTo(&command_buffer, 0))) {
                            refresh = true;
                            try stdout.print("=> refresh\n", .{});
                        } else {
                            var argv = [_][]const u8{undefined} ** 32;
                            var it = std.mem.split(u8, std.mem.sliceTo(&command_buffer, 0), " ");

                            var i: usize = 0;
                            while (it.next()) |word| : (i += 1) {
                                argv[i] = word;
                            }

                            const old_opts = opts;

                            opts.parse(argv[0..i]) catch {
                                try stdout.print("=> error during parse.\n", .{});
                                break;
                            };

                            if (!std.mem.eql(u8, std.mem.asBytes(&old_opts), std.mem.asBytes(&opts)))
                                try stdout.print("=> ok\n", .{})
                            else
                                try stdout.print("=> no change\n", .{});
                        }
                    } else if (key.keycode == .backspace) {
                        if (command_cursor > 0) {
                            command_cursor -= 1;
                            command_buffer[command_cursor] = 0;
                            // print backspace so terminal updates
                            try stdout.print("{c} {c}", .{ 0x08, 0x08 });
                        }
                    } else {
                        const char: ?u8 = blk: {
                            const num = @intFromEnum(key.keycode);
                            break :blk if (num & 0xff == num)
                                @intCast(num)
                            else
                                null;
                        };

                        if (char) |c| {
                            try stdout.print("{c}", .{c});
                            command_buffer[command_cursor] = c;
                            command_cursor += 1;
                            if (command_cursor >= command_buffer.len)
                                command_cursor = command_buffer.len;
                        }
                    }
                },
                else => {},
            }
            if (refresh) {
                heap.deinit();
                heap = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                opts.newSeed();

                blk: {
                    var next_maze_qan = dispatch(opts, heap.allocator()) catch |e| {
                        std.debug.print("An error occured: {}\nPlease pick different settings.\n", .{e});
                        break :blk;
                    };

                    maze_qan = next_maze_qan;
                    sdl2.c.SDL_SetWindowSize(sdl_window.ptr, @intCast(maze_qan.width), @intCast(maze_qan.height));
                    sdl_tex = try maze_qan.encodeSdl(sdl_renderer);
                }
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
    opt.print(std.io.getStdOut().writer());

    var grid = try Grid.init(alloc, opt.seed, opt.width, opt.height);
    defer grid.deinit();

    {
        std.debug.print("Generating... ", .{});
        var timer = try std.time.Timer.start();
        try maze.onByName(&opt.type, &grid);
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
        std.debug.print("- {} dead ends ({d}%) (Calculated in {} microseconds)\n", .{ deadends.len, @as(f64, @floatFromInt(deadends.len)) / @as(f64, @floatFromInt(grid.size())) * 100, time / 1000 });
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
        var qanv = try maze.makeQanvas(grid, opt.qoi_walls, opt.qoi_bg, opt.scale, opt.inset);
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
