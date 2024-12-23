const std = @import("std");

pub const zixelImage = @import(
    "ZixelImage.zig",
);

// Help message
const usage =
    \\Usage: ./zixel [options]
    \\Generate sixel from input image. Use scale=1 for images with transparency.
    \\
    \\Options:
    \\  -i, --image IMAGE     Set input image to IMAGE
    \\  -s, --scale FACTOR    Scale image by FACTOR, ignores -x and -y
    \\  -x, --width WIDTH     Set output sixel image width to WIDTH (default: 200)
    \\  -y, --height HEIGHT   Set output sixel image height to HEIGHT (default: 200)
    \\  -c, --colors NUM      Set the number of colors to NUM (default: 256)
    \\  -t, --threshold NUM   Set the alpha threshold to NUM (default: 0)
    \\  -h, --help            Show this help and exit
    \\
;

pub fn main() !void {
    // Memory allocations definitions
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    // Command line parameters
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var opt_image: ?[]const u8 = null;
    var opt_scale: ?f32 = null;
    var opt_width: ?usize = null;
    var opt_height: ?usize = null;
    var opt_threshold: ?u8 = null;
    var opt_colors: ?usize = null;
    //
    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or //
                std.mem.eql(u8, "--help", arg))
            {
                try std.io.getStdOut().writeAll(usage);
                return std.process.cleanExit();
            } else if (std.mem.eql(u8, "-i", arg) or //
                std.mem.eql(u8, "--image", arg))
            {
                i += 1;
                if (i >= args.len) std.zig.fatal(
                    "Expected image path after '{s}'.",
                    .{arg},
                );
                if (opt_image != null) std.zig.fatal(
                    "Duplicate argument {s}.",
                    .{arg},
                );
                opt_image = args[i];
                if (opt_image.?.len == 0) opt_image = null;
            } else if (std.mem.eql(u8, "-s", arg) or //
                std.mem.eql(u8, "--scale", arg))
            {
                i += 1;
                if (i >= args.len) std.zig.fatal(
                    "Expected an floating point number after '{s}'.",
                    .{arg},
                );
                if (opt_scale != null) std.zig.fatal(
                    "Duplicate argument {s}.",
                    .{arg},
                );
                opt_scale = try std.fmt.parseFloat(f32, args[i]);
                if (opt_scale.? <= 0) std.zig.fatal(
                    "Scale must be greater than 0.",
                    .{},
                );
            } else if (std.mem.eql(u8, "-x", arg) or //
                std.mem.eql(u8, "--width", arg))
            {
                i += 1;
                if (i >= args.len) std.zig.fatal(
                    "Expected an integer after '{s}'.",
                    .{arg},
                );
                if (opt_width != null) std.zig.fatal(
                    "Duplicate argument {s}.",
                    .{arg},
                );
                opt_width = try std.fmt.parseInt(usize, args[i], 10);
                if (opt_width == 0) std.zig.fatal(
                    "Width must be greater than 0.",
                    .{},
                );
            } else if (std.mem.eql(u8, "-y", arg) or //
                std.mem.eql(u8, "--height", arg))
            {
                i += 1;
                if (i >= args.len) std.zig.fatal(
                    "Expected an integer after '{s}'.",
                    .{arg},
                );
                if (opt_height != null) std.zig.fatal(
                    "Duplicate argument {s}.",
                    .{arg},
                );
                opt_height = try std.fmt.parseInt(usize, args[i], 10);
                if (opt_height == 0) std.zig.fatal(
                    "Height must be greater than 0.",
                    .{},
                );
            } else if (std.mem.eql(u8, "-t", arg) or //
                std.mem.eql(u8, "--threshold", arg))
            {
                i += 1;
                if (i >= args.len) std.zig.fatal(
                    "Expected an integer after '{s}'.",
                    .{arg},
                );
                if (opt_height != null) std.zig.fatal(
                    "Duplicate argument {s}.",
                    .{arg},
                );
                opt_threshold = try std.fmt.parseInt(u8, args[i], 10);
                // if (opt_height == 0) std.zig.fatal(
                //     "Height must be greater than 0.",
                //     .{},
                // );
            } else if (std.mem.eql(u8, "-c", arg) or //
                std.mem.eql(u8, "--colors", arg))
            {
                i += 1;
                if (i >= args.len) std.zig.fatal(
                    "Expected an integer after '{s}'.",
                    .{arg},
                );
                if (opt_colors != null) std.zig.fatal(
                    "Duplicate argument {s}.",
                    .{arg},
                );
                opt_colors = try std.fmt.parseInt(usize, args[i], 10);
                if (opt_colors == 0) std.zig.fatal(
                    "Number of colors must be greater than 0.",
                    .{},
                );
            }
        }
    }
    if (opt_image == null) {
        try std.io.getStdOut().writeAll(usage);
        return std.process.cleanExit();
    }
    const the_image = opt_image.?;
    const the_scale: ?f32 = opt_scale;
    var the_width: usize = opt_width orelse 200;
    var the_height: usize = opt_height orelse 200;
    const the_threshold: ?u8 = opt_threshold;
    const the_colors: usize = opt_colors orelse 256;
    //
    var img = try zixelImage.openImage(
        &allocator,
        the_image,
    );
    defer img.deinit();
    zixelImage.getNewSize(
        the_scale,
        &the_width,
        &the_height,
        img.width,
        img.height,
    );
    var buf_writer = std.io.bufferedWriter(
        std.io.getStdOut().writer(),
    );
    defer _ = buf_writer.flush() catch unreachable;
    if (the_threshold) |th| {
        var image = try zixelImage.resizeSimpleRGBA(
            &allocator,
            &img,
            the_width,
            the_height,
        );
        defer image.deinit();
        _ = try zixelImage.sixelMakerRGBA(
            &buf_writer,
            &allocator,
            image,
            the_colors,
            th,
        );
    } else {
        var image = try zixelImage.resizeSimpleRGB(
            &allocator,
            &img,
            the_width,
            the_height,
        );
        defer image.deinit();
        _ = try zixelImage.sixelMaker(
            &buf_writer,
            &allocator,
            image,
            the_colors,
        );
    }
}
