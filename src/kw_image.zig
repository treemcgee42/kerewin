const std = @import("std");
const c = @import("c.zig");

pub const ImageLoadError = error{
    Failed,
    LoadFileError,
    NotImageFile,
    NoPixels,
    NoMemory,
};

pub const KwImage = struct {
    bytes_per_pixel: u8 = 4,
    data: ?[]u8,
    image_width: u32,
    image_height: u32,
    bytes_per_scanline: u32,

    pub fn init_null() KwImage {
        return KwImage{
            .data = null,
            .image_width = 0,
            .image_height = 0,
            .bytes_per_scanline = 0,
        };
    }

    pub fn init_filename(filename: []const u8, allocator: std.mem.Allocator) !KwImage {
        var self = KwImage.init_null();

        try self.load(filename, allocator);

        return self;
    }

    pub fn deinit(self: *KwImage) void {
        c.stbi_image_free(self.data);
    }

    /// Loads image data from the given filename. Returns true if the image was
    /// loaded successfully, false otherwise.
    fn load(self: *KwImage, filename: []const u8, allocator: std.mem.Allocator) !void {
        // First load the file into memory.
        const file = try std.fs.cwd().openFile(
            filename,
            .{},
        );
        defer file.close();

        var buf = file.readToEndAlloc(allocator, 4096 * 4096 * 3) catch |err| {
            std.debug.print("Failed to load file into memory: {}\n", .{err});
            return ImageLoadError.LoadFileError;
        };

        // Now do stb stuff.
        var kw_image: KwImage = undefined;

        var w: c_int = undefined;
        var h: c_int = undefined;

        if (c.stbi_info_from_memory(buf.ptr, @intCast(buf.len), &w, &h, null) == 0) {
            return ImageLoadError.NotImageFile;
        }

        if (w <= 0 or h <= 0) {
            return ImageLoadError.NoPixels;
        }
        kw_image.image_width = @intCast(w);
        kw_image.image_height = @intCast(h);

        const image_data = c.stbi_load_from_memory(
            buf.ptr,
            @intCast(buf.len),
            &w,
            &h,
            null,
            4,
        );
        if (image_data == null) {
            return ImageLoadError.NoMemory;
        }

        kw_image.bytes_per_scanline = kw_image.image_width * @as(u32, @intCast(self.bytes_per_pixel));
        kw_image.data = image_data[0 .. kw_image.bytes_per_scanline * kw_image.image_height];

        self.* = kw_image;
        self.bytes_per_pixel = 4;
    }

    pub fn width(self: *const KwImage) u32 {
        if (self.data == null) {
            return 0;
        }

        return self.image_width;
    }

    pub fn height(self: *const KwImage) u32 {
        if (self.data == null) {
            return 0;
        }

        return self.image_height;
    }

    const magenta = [_]u8{ 255, 0, 255 };

    pub fn pixel_data(self: *const KwImage, x: u32, y: u32) []const u8 {
        if (self.data == null) {
            return magenta[0..];
        }

        const x_clamped = clamp(x, 0, self.image_width);
        const y_clamped = clamp(y, 0, self.image_height);

        const start_idx: usize = (y_clamped * self.bytes_per_scanline) + (x_clamped * self.bytes_per_pixel);

        return self.data.?[start_idx..(start_idx + 3)];
    }

    fn clamp(x: u32, min: u32, max: u32) u32 {
        if (x < min) {
            return min;
        } else if (x > max) {
            return max;
        } else {
            return x;
        }
    }
};
