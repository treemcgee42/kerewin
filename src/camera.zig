const math = @import("math/math.zig");
const color = @import("color.zig");
const object = @import("object.zig");
const material = @import("material.zig");
const std = @import("std");
const TextureSystem = @import("texture.zig").TextureSystem;

pub const Camera = struct {
    aspect_ratio: f64,
    image_width: u32,
    samples_per_pixel: u32,
    max_depth: u32,

    vfov: f64,
    look_from: math.vec.Point3,
    look_at: math.vec.Point3,
    v_up: math.vec.Vec3,

    defocus_angle: f64,
    focus_dist: f64,

    image_height: u32,
    center: math.vec.Point3,
    pixel00_loc: math.vec.Point3, // Location of pixel 0, 0.
    pixel_delta_u: math.vec.Vec3, // Ofset to pixel to the right.
    pixel_delta_v: math.vec.Vec3, // Offset to piixel below.
    u: math.vec.Vec3, // Camera frame basis vectors.
    v: math.vec.Vec3,
    w: math.vec.Vec3,
    defocus_disk_u: math.vec.Vec3, // Defocus disk horizontal radius.
    defocus_disk_v: math.vec.Vec3, // Defocus disk vertical radius.

    material_system: *material.MaterialSystem,
    texture_system: *TextureSystem,

    pub const InitParams = struct {
        aspect_ratio: f64 = 1.0,
        image_width: u32 = 100,
        samples_per_pixel: u32 = 10,
        max_depth: u32 = 10,

        vfov: f64 = 90.0,
        look_from: math.vec.Point3 = math.vec.Point3{ 0.0, 0.0, -1.0 },
        look_at: math.vec.Point3 = math.vec.Point3{ 0.0, 0.0, 0.0 },
        v_up: math.vec.Vec3 = math.vec.Vec3{ 0.0, 1.0, 0.0 },

        defocus_angle: f64 = 0.0, // Variation angle of rays through each pixel.
        focus_dist: f64 = 10.0, // Distance from camera look_from point to plane of perfect focus.

        material_system: *material.MaterialSystem,
        texture_system: *TextureSystem,
    };

    pub fn init(params: InitParams) Camera {
        var image_height: u32 = @intFromFloat(@as(f64, @floatFromInt(params.image_width)) / params.aspect_ratio);
        if (image_height < 1) {
            image_height = 1;
        }

        const center = params.look_from;

        // Determine viewport dimensions.
        const theta = math.deg_to_rad(params.vfov);
        const h = @tan(theta / 2.0);
        const viewport_height: f64 = 2.0 * h * params.focus_dist;
        const viewport_width: f64 = (@as(f64, @floatFromInt(params.image_width)) / @as(f64, @floatFromInt(image_height))) * viewport_height;

        // Calculate the u,v,w unit basic vectors for the camera coordinate frame.
        const w = math.vec.normalize_vec3(params.look_from - params.look_at);
        const u = math.vec.normalize_vec3(math.vec.cross_vec3(params.v_up, w));
        const v = math.vec.cross_vec3(w, u);

        // Calculate the vectors across the horizontal and down the vertical viewport edges.
        const viewport_u = math.vec.mul_scalar_vec3(viewport_width, u);
        const viewport_v = math.vec.mul_scalar_vec3(viewport_height, -v);

        // Calculate the horizontal and vertical delta vectors from pixel to pixel.
        const pixel_delta_u = math.vec.div_vec3_scalar(viewport_u, @floatFromInt(params.image_width));
        const pixel_delta_v = math.vec.div_vec3_scalar(viewport_v, @floatFromInt(image_height));

        // Calculate the location of the upper left pixel.
        const viewport_upper_left = center - math.vec.mul_scalar_vec3(params.focus_dist, w) - math.vec.div_vec3_scalar(viewport_u, 2.0) - math.vec.div_vec3_scalar(viewport_v, 2.0);
        const pixel00_loc = viewport_upper_left + math.vec.mul_scalar_vec3(0.5, pixel_delta_u + pixel_delta_v);

        // Calculate the camera defocus disk basis vectors.
        const defocus_radius = params.focus_dist * @tan(math.deg_to_rad(params.defocus_angle / 2.0));
        const defocus_disk_u = math.vec.mul_scalar_vec3(defocus_radius, u);
        const defocus_disk_v = math.vec.mul_scalar_vec3(defocus_radius, v);

        return .{
            .aspect_ratio = params.aspect_ratio,
            .image_width = params.image_width,
            .samples_per_pixel = params.samples_per_pixel,
            .max_depth = params.max_depth,

            .vfov = params.vfov,
            .look_from = params.look_from,
            .look_at = params.look_at,
            .v_up = params.v_up,

            .defocus_angle = params.defocus_angle,
            .focus_dist = params.focus_dist,

            .image_height = image_height,
            .center = center,
            .pixel00_loc = pixel00_loc,
            .pixel_delta_u = pixel_delta_u,
            .pixel_delta_v = pixel_delta_v,
            .u = u,
            .v = v,
            .w = w,
            .defocus_disk_u = defocus_disk_u,
            .defocus_disk_v = defocus_disk_v,

            .material_system = params.material_system,
            .texture_system = params.texture_system,
        };
    }

    pub fn ray_color(texture_system: *const TextureSystem, r: *const math.ray.Ray3, depth: u32, world: *object.ObjectList, material_system: *material.MaterialSystem) color.Color3 {
        if (depth <= 0) {
            return color.Color3{ 0.0, 0.0, 0.0 };
        }

        var rec = object.HitRecord{
            .t = 0.0,
            .p = math.vec.Point3{ 0.0, 0.0, 0.0 },
            .normal = math.vec.Vec3{ 0.0, 0.0, 0.0 },
            .is_front_face = false,
            .mat = material.MaterialSystem.MaterialHandle{ .index = 0 },
        };

        if (world.intersect(r, math.interval.Interval{ .min = 0.001, .max = math.infinity }, &rec)) {
            var scattered = math.ray.Ray3.init_without_time(rec.p, math.vec.Vec3{ 0.0, 0.0, 0.0 });
            var attenuation = color.Color3{ 0.0, 0.0, 0.0 };

            if (material_system.scatter(texture_system, rec.mat, r, &rec, &attenuation, &scattered)) {
                return attenuation * ray_color(texture_system, &scattered, depth - 1, world, material_system);
            }

            return color.Color3{ 0.0, 0.0, 0.0 };
        }

        var unit_direction = math.vec.normalize_vec3(r.direction);
        var a = 0.5 * (unit_direction[1] + 1.0);
        return math.vec.mul_scalar_vec3(1.0 - a, color.Color3{ 1.0, 1.0, 1.0 }) + math.vec.mul_scalar_vec3(a, color.Color3{ 0.5, 0.7, 1.0 });
    }

    fn pixel_sample_square(self: *const Camera) math.vec.Vec3 {
        const px = -0.5 + math.random_f64();
        const py = -0.5 + math.random_f64();
        return math.vec.mul_scalar_vec3(px, self.pixel_delta_u) + math.vec.mul_scalar_vec3(py, self.pixel_delta_v);
    }

    fn defocus_disk_sample(self: *const Camera) math.vec.Point3 {
        const p = math.random_in_unit_disk();
        return self.center + math.vec.mul_scalar_vec3(p[0], self.defocus_disk_u) + math.vec.mul_scalar_vec3(p[1], self.defocus_disk_v);
    }

    /// Get a randomly-sampled camera ray for the pixel at location (i, j) originating from the camera defocus disk.
    fn get_ray(self: *const Camera, i: u32, j: u32) math.ray.Ray3 {
        const pixel_center = self.pixel00_loc + math.vec.mul_scalar_vec3(@floatFromInt(i), self.pixel_delta_u) + math.vec.mul_scalar_vec3(@floatFromInt(j), self.pixel_delta_v);
        const pixel_sample = pixel_center + self.pixel_sample_square();

        var ray_origin = self.defocus_disk_sample();
        if (self.defocus_angle <= 0.0) {
            ray_origin = self.center;
        }
        const ray_direction = pixel_sample - ray_origin;
        const ray_time = math.random_f64();

        return math.ray.Ray3{ .origin = ray_origin, .direction = ray_direction, .time = ray_time };
    }

    pub fn render(self: *const Camera, world: *object.ObjectList, writer: anytype) !void {
        try writer.print("P3\n{} {}\n255\n", .{ self.image_width, self.image_height });

        var j: usize = 0;
        while (j < self.image_height) : (j += 1) {
            const remaining_scanlines = self.image_height - j;
            const percentage_done = 100.0 * @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(self.image_height));
            std.debug.print("\r[{d:.0}%] Scanlines remaining: {}", .{ percentage_done, remaining_scanlines });

            var i: usize = 0;
            while (i < self.image_width) : (i += 1) {
                var pixel_color = color.Color3{ 0.0, 0.0, 0.0 };
                var s: u32 = 0;
                while (s < self.samples_per_pixel) : (s += 1) {
                    const r = self.get_ray(@intCast(i), @intCast(j));
                    pixel_color += ray_color(self.texture_system, &r, self.max_depth, world, self.material_system);
                }

                try color.write_color3(pixel_color, self.samples_per_pixel, writer);
            }
        }

        std.debug.print("\rDone.\n", .{});
    }
};
