const std = @import("std");
const raylib = @import("c.zig").raylib;

pub const KwImage = struct {
    bytes_per_pixel: u8 = 4,
    data: ?[]u8,
    image_width: u32,
    image_height: u32,
    bytes_per_scanline: u32,
    raylib_image: raylib.Image,

    pub fn init_null() KwImage {
        return KwImage{
            .data = null,
            .image_width = 0,
            .image_height = 0,
            .bytes_per_scanline = 0,
            .raylib_image = undefined,
        };
    }

    pub fn init_filename(filename: []const u8, allocator: std.mem.Allocator) !KwImage {
        _ = allocator;
        var self = KwImage.init_null();

        self.raylib_image = raylib.LoadImage(filename.ptr);

        return self;
    }

    pub fn deinit(self: *KwImage) void {
        raylib.UnloadImage(self.raylib_image);
    }

    pub fn width(self: *const KwImage) u32 {
        return @as(u32, @intCast(self.raylib_image.width));
    }

    pub fn height(self: *const KwImage) u32 {
        return @as(u32, @intCast(self.raylib_image.height));
    }

    const magenta = [_]u8{ 255, 0, 255 };

    pub fn pixel_data(self: *const KwImage, x: u32, y: u32) [3]u8 {
        const color = raylib.GetImageColor(self.raylib_image, @as(c_int, @intCast(x)), @as(c_int, @intCast(y)));

        return [_]u8{
            color.r,
            color.g,
            color.b,
        };
    }
};
