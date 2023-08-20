const std = @import("std");
const math = @import("math/math.zig");
const Color3 = @import("color.zig").Color3;
const KwImage = @import("kw_image.zig").KwImage;

const SolidColor = struct {
    color_value: math.vec.Vec3,

    pub inline fn init_rgb(color: Color3) SolidColor {
        return .{ .color_value = color };
    }
};

const CheckerTexture = struct {
    inv_scale: f64,
    even: TextureSystem.TextureHandle,
    odd: TextureSystem.TextureHandle,

    pub fn init_textures(scale: f64, even: TextureSystem.TextureHandle, odd: TextureSystem.TextureHandle) CheckerTexture {
        return .{
            .even = even,
            .odd = odd,
            .inv_scale = 1.0 / scale,
        };
    }

    pub fn init_colors(texture_system: *TextureSystem, scale: f64, even: math.vec.Vec3, odd: math.vec.Vec3) !CheckerTexture {
        const ev = try texture_system.create_SolidColor(even);
        const od = try texture_system.create_SolidColor(odd);
        return .{
            .even = ev,
            .odd = od,
            .inv_scale = 1.0 / scale,
        };
    }

    pub fn value(self: *const CheckerTexture, system: *const TextureSystem, u: f64, v: f64, p: math.vec.Vec3) math.vec.Vec3 {
        const x_int: i32 = @intFromFloat(@floor(self.inv_scale * p[0]));
        const y_int: i32 = @intFromFloat(@floor(self.inv_scale * p[1]));
        const z_int: i32 = @intFromFloat(@floor(self.inv_scale * p[2]));

        const is_even: bool = @mod((x_int + y_int + z_int), 2) == 0;

        return switch (is_even) {
            true => system.value(self.even, u, v, p),
            false => system.value(self.odd, u, v, p),
        };
    }
};

const ImageTexture = struct {
    image: KwImage,

    pub fn init_filename(filename: []const u8, allocator: std.mem.Allocator) !ImageTexture {
        const image = try KwImage.init_filename(filename, allocator);
        return .{ .image = image };
    }

    pub fn value(self: *const ImageTexture, u: f64, v: f64, p: math.vec.Point3) Color3 {
        _ = p;

        // If we have no texture data, then return solid cyan as a debugging aid.
        if (self.image.height() <= 0) {
            return Color3{ 0.0, 1.0, 1.0 };
        }

        // Clamp input texture coordinates to [0,1] x [1,0]
        const u_clamped = math.interval.Interval.init_with_floats(0.0, 1.0).clamp(u);
        const v_clamped = 1.0 - math.interval.Interval.init_with_floats(0.0, 1.0).clamp(v);

        const i: u32 = @intFromFloat(u_clamped * @as(f64, @floatFromInt(self.image.width())));
        const j: u32 = @intFromFloat(v_clamped * @as(f64, @floatFromInt(self.image.height())));
        const pixel = self.image.pixel_data(i, j);

        const color_scale = 1.0 / 255.0;
        return Color3{
            color_scale * @as(f64, @floatFromInt(pixel[0])),
            color_scale * @as(f64, @floatFromInt(pixel[1])),
            color_scale * @as(f64, @floatFromInt(pixel[2])),
        };
    }
};

pub const TextureSystem = struct {
    data: std.ArrayList(Data),

    const Data = union(enum) {
        solid_color: SolidColor,
        checker_texture: CheckerTexture,
        image_texture: ImageTexture,
    };

    pub const TextureHandle = struct {
        data_idx: usize,
    };

    pub fn init(allocator: std.mem.Allocator) TextureSystem {
        return .{
            .data = std.ArrayList(Data).init(allocator),
        };
    }

    pub fn deinit(self: *TextureSystem) void {
        self.data.deinit();
    }

    pub fn create_SolidColor(self: *TextureSystem, color: Color3) !TextureHandle {
        try self.data.append(Data{ .solid_color = SolidColor.init_rgb(color) });
        const data_idx = self.data.items.len - 1;

        return .{ .data_idx = data_idx };
    }

    pub fn create_CheckerTexture_colors(self: *TextureSystem, scale: f64, even: math.vec.Vec3, odd: math.vec.Vec3) !TextureHandle {
        const d = try CheckerTexture.init_colors(self, scale, even, odd);
        try self.data.append(Data{ .checker_texture = d });
        const data_idx = self.data.items.len - 1;

        return .{ .data_idx = data_idx };
    }

    pub fn create_ImageTexture_filename(self: *TextureSystem, filename: []const u8, allocator: std.mem.Allocator) !TextureHandle {
        const d = try ImageTexture.init_filename(filename, allocator);
        try self.data.append(Data{ .image_texture = d });
        const data_idx = self.data.items.len - 1;

        return .{ .data_idx = data_idx };
    }

    pub fn value(self: *const TextureSystem, handle: TextureHandle, u: f64, v: f64, p: math.vec.Vec3) math.vec.Vec3 {
        const data = self.data.items[handle.data_idx];

        return switch (data) {
            .solid_color => |*sc| sc.color_value,
            .checker_texture => |*ct| CheckerTexture.value(ct, self, u, v, p),
            .image_texture => |*it| ImageTexture.value(it, u, v, p),
        };
    }
};
