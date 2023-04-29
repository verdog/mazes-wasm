    text: bool = true,
    qoi: bool = false,
    qoi_walls: bool = true,
    qoi_bg: bool = true,
    braid: f64 = 0,
    seed: u64 = 0,
    width: u32 = 8,
    height: u32 = 8,
    scale: usize = 64,
    inset: f64 = 0,
    type: [64]u8 = u.strBuf(64, "recursivebacktracker"),
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
            const arg = std.mem.sliceTo(sarg, '0');

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
            } else if (eq(u8, "--qoi-bg", arg)) {
                opts.qoi_bg = true;
            } else if (eq(u8, "--noqoi-bg", arg)) {
                opts.qoi_bg = false;
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
                                std.mem.copy(u8, &opts.type, right);
                                opts.type[right.len] = 0;
                            } else {
                                for (@typeInfo(maze).Struct.decls) |dec| {
                                    if (eq(u8, dec.name, right)) {
                                        std.mem.copy(u8, &opts.type, right);
                                        opts.type[right.len] = 0;
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
            \\ - qoi_bg: {}
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
            opt.qoi_bg,
            opt.braid,
            opt.seed,
            opt.width,
            opt.height,
            opt.scale,
            opt.inset,
            std.mem.sliceTo(&opt.type, 0),
            u.eString(Options.Vizualization, opt.viz),
            u.eString(Options.Grid, opt.grid),
        });
    }
