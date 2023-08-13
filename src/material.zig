const std = @import("std");
const color = @import("color.zig");
const math = @import("math/math.zig");
const HitRecord = @import("object.zig").HitRecord;

const Lambertian = struct {
    albedo: color.Color3,

    fn scatter(self: *const Lambertian, r_in: *const math.ray.Ray3, rec: *const HitRecord, attenuation: *color.Color3, scattered: *math.ray.Ray3) bool {
        _ = r_in;

        var scatter_direction = rec.normal + math.random_unit_vector();

        // Catch degenerate scatter direction.
        if (math.vec.near_zero_vec3(scatter_direction)) {
            scatter_direction = rec.normal;
        }

        scattered.origin = rec.p;
        scattered.direction = scatter_direction;
        attenuation.* = self.albedo;
        return true;
    }
};

const Metal = struct {
    albedo: color.Color3,
    fuzz: f64,

    fn scatter(self: *const Metal, r_in: *const math.ray.Ray3, rec: *const HitRecord, attenuation: *color.Color3, scattered: *math.ray.Ray3) bool {
        const reflected = math.vec.reflect_vec3(math.vec.normalize_vec3(r_in.direction), rec.normal);
        scattered.origin = rec.p;
        scattered.direction = reflected + math.vec.mul_scalar_vec3(self.fuzz, math.random_unit_vector());
        attenuation.* = self.albedo;
        return math.vec.dot_vec3(scattered.direction, rec.normal) > 0.0;
    }
};

const Dielectric = struct {
    ior: f64,

    fn reflectance(cosine: f64, ref_idx: f64) f64 {
        // Use Schlick's approximation for reflectance.
        var r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
        r0 = r0 * r0;
        return r0 + (1.0 - r0) * std.math.pow(f64, (1.0 - cosine), 5.0);
    }

    fn scatter(self: *const Dielectric, r_in: *const math.ray.Ray3, rec: *const HitRecord, attenuation: *color.Color3, scattered: *math.ray.Ray3) bool {
        attenuation.* = .{ 1.0, 1.0, 1.0 };

        var refraction_ratio = self.ior;
        if (rec.is_front_face) {
            refraction_ratio = 1.0 / self.ior;
        }

        const unit_direction = math.vec.normalize_vec3(r_in.direction);
        const cos_theta = @min(math.vec.dot_vec3(-unit_direction, rec.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

        const cannot_refract = refraction_ratio * sin_theta > 1.0;
        var direction = math.vec.refract_vec3(unit_direction, rec.normal, refraction_ratio);
        if (cannot_refract or Dielectric.reflectance(cos_theta, refraction_ratio) > math.random_f64()) {
            direction = math.vec.reflect_vec3(unit_direction, rec.normal);
        }

        scattered.origin = rec.p;
        scattered.direction = direction;
        return true;
    }
};

pub const MaterialSystem = struct {
    data: std.ArrayList(Data),

    const Data = union(enum) {
        lambertian: Lambertian,
        metal: Metal,
        dielectric: Dielectric,
    };

    pub const MaterialHandle = struct {
        index: usize,
    };

    pub fn init(allocator: std.mem.Allocator) MaterialSystem {
        return .{
            .data = std.ArrayList(Data).init(allocator),
        };
    }

    pub fn deinit(self: *MaterialSystem) void {
        self.data.deinit();
    }

    pub fn create_Lambertian(self: *MaterialSystem, albedo: color.Color3) !MaterialHandle {
        const data_index = self.data.items.len;
        const lamb = Data{ .lambertian = Lambertian{ .albedo = albedo } };
        try self.data.append(lamb);

        return .{ .index = data_index };
    }

    pub fn create_Metal(self: *MaterialSystem, albedo: color.Color3, fuzz: f64) !MaterialHandle {
        const data_index = self.data.items.len;
        const met = Data{ .metal = Metal{ .albedo = albedo, .fuzz = fuzz } };
        try self.data.append(met);
        return .{ .index = data_index };
    }

    pub fn create_Dielectric(self: *MaterialSystem, ior: f64) !MaterialHandle {
        const data_index = self.data.items.len;
        const die = Data{ .dielectric = Dielectric{ .ior = ior } };
        try self.data.append(die);

        return .{ .index = data_index };
    }

    pub fn scatter(self: *const MaterialSystem, material: MaterialHandle, r_in: *const math.ray.Ray3, rec: *const HitRecord, attenuation: *color.Color3, scattered: *math.ray.Ray3) bool {
        return switch (self.data.items[material.index]) {
            Data.lambertian => |*lamb| lamb.scatter(r_in, rec, attenuation, scattered),
            Data.metal => |*met| met.scatter(r_in, rec, attenuation, scattered),
            Data.dielectric => |*die| die.scatter(r_in, rec, attenuation, scattered),
        };
    }
};
