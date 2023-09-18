const std = @import("std");
const colorlib = @import("color.zig");
const Color3 = @import(".//color.zig").Color3;
const raylib = @import("./c.zig").raylib;

width: u32,
height: u32,
pixels: []Color3,
completed_samples: u32,
sync: Sync,

current_progress: f32,
max_progress: f32,

pub const Sync = struct {
    should_read: bool,
};

const PartialRender = @This();

pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !PartialRender {
    var pixels = try allocator.alloc(Color3, width * height);
    for (pixels) |*p| {
        p.* = Color3{ 0, 0, 0 };
    }

    return .{
        .width = width,
        .height = height,
        .pixels = pixels,
        .completed_samples = 0,
        .sync = Sync{ .should_read = false },

        .current_progress = 0.0,
        .max_progress = 1.0,
    };
}

pub fn deinit(self: *PartialRender, allocator: std.mem.Allocator) void {
    allocator.free(self.pixels);
}

/// Loads a blank raylib image with the correct size. Caller is responsible for unloading the image.
pub fn load_raylib_image(self: *PartialRender) raylib.Image {
    return raylib.GenImageColor(
        @as(c_int, @intCast(self.width)),
        @as(c_int, @intCast(self.height)),
        raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    );
}

/// Caller is responsible for unloading the image.
///
/// Warning: do you really need to use this function? If you're making frequent updates, it might be
/// better to create a blank image (`load_raylib_image()`) and update it (`update_raylib_image()`).
pub fn create_raylib_image(self: *PartialRender) raylib.Image {
    var image = raylib.GenImageColor(
        @as(c_int, @intCast(self.width)),
        @as(c_int, @intCast(self.height)),
        raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    );

    var x: u32 = 0;
    var y: u32 = 0;
    var color: Color3 = undefined;
    while (y < self.height) : (y += 1) {
        while (x < self.width) : (x += 1) {
            color = self.pixels[y * self.width + x];

            raylib.ImageDrawPixel(
                &image,
                @as(c_int, @intCast(x)),
                @as(c_int, @intCast(y)),
                raylib.Color{
                    .r = @as(u8, @intFromFloat(color[0] / @as(f64, self.completed_samples))),
                    .g = @as(u8, @intFromFloat(color[1] / @as(f64, self.completed_samples))),
                    .b = @as(u8, @intFromFloat(color[2] / @as(f64, self.completed_samples))),
                    .a = 255,
                },
            );
        }
    }

    return image;
}

pub fn update_raylib_image(self: *PartialRender, raylib_image: *raylib.Image) void {
    var x: u32 = 0;
    var y: u32 = 0;
    var c: Color3 = undefined;
    var processed_color: [3]u8 = undefined;
    while (y < self.height) : (y += 1) {
        x = 0;
        while (x < self.width) : (x += 1) {
            c = self.pixels[y * self.width + x];
            processed_color = colorlib.process_color3(&c, self.completed_samples);

            raylib.ImageDrawPixel(
                raylib_image,
                @as(c_int, @intCast(x)),
                @as(c_int, @intCast(y)),
                raylib.Color{
                    .r = processed_color[0],
                    .g = processed_color[1],
                    .b = processed_color[2],
                    .a = 255,
                },
            );
        }
    }
}

fn clamp(value: f64) f64 {
    if (value < 0.0) {
        return 0.0;
    } else if (value > 255.0) {
        return 255.0;
    } else {
        return value;
    }
}

pub fn add_equal_pixel_color(self: *PartialRender, pixel_x: u32, pixel_y: u32, c: Color3) void {
    self.pixels[pixel_y * self.width + pixel_x] += c;
}
