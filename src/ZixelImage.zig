const std = @import("std");
const zigimg = @import("zigimg");

/// Maximum output color for the sixel
pub const MAX_PALETTE_SIZE = 256;

/// Generate sixel image from input image (PNG?)
pub fn sixelMaker(
    /// Buffer writer to print sixel to the stdout
    writer: anytype,
    /// Name of input image file
    filename: []const u8,
    /// Scale image instead of using width/height
    scale: ?f32,
    /// Width of the sixel
    width: usize,
    /// Height of the sixel
    height: usize,
    /// Number of colors allowed in the sixel
    number_colors: usize,
) !u8 {
    const MaxRGB: usize = 255;
    var new_scale: ?f32 = null;
    var new_width: usize = 200;
    var new_height: usize = 200;
    if (scale) |s| {
        if (s <= 0) new_scale = scale;
    }
    if (width > 0) {
        new_width = width;
    }
    if (height > 0) {
        new_height = height;
    }
    var num_colors: usize = MAX_PALETTE_SIZE;
    if (number_colors < MAX_PALETTE_SIZE) {
        num_colors = number_colors;
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var image = try zigimg.Image.fromFilePath(
        allocator,
        filename,
    );
    defer image.deinit();

    const original_width = image.width;
    const original_height = image.height;

    if (scale) |_| {
        const fw: f32 = @floatFromInt(original_width);
        const fh: f32 = @floatFromInt(original_height);
        const nw: usize = @intFromFloat(fw * new_scale.?);
        const nh: usize = @intFromFloat(fh * new_scale.?);
        if (nw > 0) new_width = nw;
        if (nh > 0) new_height = nh;
    }

    // Resized image
    var image_resized = try zigimg.Image.create(
        allocator,
        new_width,
        new_height,
        .rgb24,
    );
    defer image_resized.deinit();

    // Make sure that input image is RGB not RGBA
    try image.convert(.rgb24);

    // RESIZE IMAGE
    for (0..new_height) |y| {
        for (0..new_width) |x| {
            const src_x: usize = x * original_width / new_width;
            const src_y: usize = y * original_height / new_height;
            const src_index = src_y * original_width + src_x;
            const dest_index = y * new_width + x;
            image_resized.pixels.rgb24[dest_index] = image.pixels.rgb24[src_index];
        }
    }

    // Quantize the image to reduce number of colors
    var quantizer = zigimg.OctTreeQuantizer.init(allocator);
    defer quantizer.deinit();

    var color_it = image_resized.iterator();

    while (color_it.next()) |pixel| {
        try quantizer.addColor(pixel);
    }

    var palette_storage: [MAX_PALETTE_SIZE]zigimg.color.Rgba32 = undefined;
    const palette = quantizer.makePalette(
        @as(u32, @intCast(num_colors)) - 1,
        palette_storage[0..],
    );

    // SIXEL STUFF
    // START
    _ = try writer.writer().print("\x1bP", .{});
    // DECLARE SIZE ETC
    const aspect_ratio: usize = 7; // set to 1:1
    const background_option: usize = 2; // 1
    const dpi: usize = 75;
    _ = try writer.writer().print(
        "{};{};{}q\"1;1;{};{}",
        .{
            aspect_ratio,
            background_option,
            dpi,
            new_width,
            new_height,
        },
    );
    // BUILD PALETTE
    for (0..palette.len) |index| {
        const color = palette[index];
        const fr: f64 = @floatFromInt(color.r);
        const fg: f64 = @floatFromInt(color.g);
        const fb: f64 = @floatFromInt(color.b);
        const r: u8 = @intFromFloat(fr * 100 / MaxRGB);
        const g: u8 = @intFromFloat(fg * 100 / MaxRGB);
        const b: u8 = @intFromFloat(fb * 100 / MaxRGB);
        _ = try writer.writer().print(
            "#{};2;{};{};{}",
            .{
                index,
                r,
                g,
                b,
            },
        );
    }
    _ = try writer.writer().print("\n", .{});
    // SIXEL BODY
    var n: i8 = 1;
    for (0..new_height) |y| {
        var count: usize = 1;
        var c: i8 = -1;
        const cached_pixel = image_resized.pixels.rgb24[y * new_width];
        var cached_no = quantizer.getPaletteIndex(
            zigimg.color.Rgba32.initRgba(
                cached_pixel.r,
                cached_pixel.g,
                cached_pixel.b,
                255,
            ),
        ) catch unreachable;
        for (0..new_width) |x| {
            const current_pixel = image_resized.pixels.rgb24[y * new_width + x];
            const current_no = quantizer.getPaletteIndex(
                zigimg.color.Rgba32.initRgba(
                    current_pixel.r,
                    current_pixel.g,
                    current_pixel.b,
                    255,
                ),
            ) catch unreachable;
            if (current_no == cached_no) {
                if (count == 1) {
                    _ = try writer.writer().print(
                        "#{}",
                        .{
                            cached_no,
                        },
                    );
                }
                count += 1;
            } else {
                // if (key_color == cached_pixel)  { c = 0x3F; } else {}
                // Inside `else`
                c = 0x3F + n;
                if (count == 1) {
                    _ = try writer.writer().print(
                        "#{}",
                        .{
                            cached_no,
                        },
                    );
                }
                if (count < 3) {
                    for (0..count) |_| {
                        _ = try writer.writer().print(
                            "{c}",
                            .{
                                @abs(c),
                            },
                        );
                    }
                } else {
                    _ = try writer.writer().print(
                        "!{}{c}",
                        .{
                            count,
                            @abs(c),
                        },
                    );
                }
                count = 1;
                cached_no = current_no;
                // cached_pixel = current_pixel;
                // End of `else`
            }
        }
        if (c != -1 and count > 1) {
            if (count < 3) {
                for (0..count) |_| {
                    _ = try writer.writer().print(
                        "{c}",
                        .{
                            @abs(c),
                        },
                    );
                }
            } else {
                _ = try writer.writer().print(
                    "!{}{c}",
                    .{
                        count,
                        @abs(c),
                    },
                );
            }
        }
        if (n == 32) {
            n = 1;
            _ = try writer.writer().print(
                "-\n",
                .{},
            );
        } else {
            n <<= 1;
            _ = try writer.writer().print(
                "$\n",
                .{},
            );
        }
    }

    //SIXEL END
    _ = try writer.writer().print(
        "\x1b\\",
        .{},
    );
    _ = try writer.flush();

    return 0;
}
