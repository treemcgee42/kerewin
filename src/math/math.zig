pub const vec = @import("vec.zig");
pub const ray = @import("ray.zig");
pub const interval = @import("interval.zig");
const std = @import("std");

pub const infinity = std.math.inf(f64);
pub const pi: f64 = std.math.pi;

var prng = std.rand.DefaultPrng.init(0);

pub fn deg_to_rad(degrees: f64) f64 {
    return @call(.always_inline, std.math.degreesToRadians, .{ f64, degrees });
}

/// Returns a random f64 in the range [0, 1).
pub inline fn random_f64() f64 {
    return prng.random().float(f64);
}

/// Returns a random f64 in the range [min, max).
pub inline fn random_f64_range(min: f64, max: f64) f64 {
    return min + (max - min) * random_f64();
}

/// Returns a random vec3 with each component in the range [0, 1).
pub inline fn random_vec3() vec.Vec3 {
    return vec.Vec3{ random_f64(), random_f64(), random_f64() };
}

/// Returns a random vec3 with each component in the range [min, max).
pub inline fn random_vec3_range(min: f64, max: f64) vec.Vec3 {
    return vec.Vec3{ random_f64_range(min, max), random_f64_range(min, max), random_f64_range(min, max) };
}

pub inline fn random_in_unit_sphere() vec.Vec3 {
    while (true) {
        const p = random_vec3_range(-1.0, 1.0);
        if (vec.length_squared_vec3(p) >= 1.0) {
            continue;
        }
        return p;
    }
}

pub inline fn random_unit_vector() vec.Vec3 {
    return vec.normalize_vec3(random_in_unit_sphere());
}

pub inline fn random_on_hemisphere(normal: vec.Vec3) vec.Vec3 {
    const on_unit_sphere = random_unit_vector();

    if (vec.dot_vec3(on_unit_sphere, normal) > 0.0) {
        return on_unit_sphere;
    } else {
        return -on_unit_sphere;
    }
}

pub inline fn random_in_unit_disk() vec.Vec3 {
    while (true) {
        const p = vec.Vec3{ random_f64_range(-1.0, 1.0), random_f64_range(-1.0, 1.0), 0.0 };
        if (vec.length_squared_vec3(p) >= 1.0) {
            continue;
        }

        return p;
    }
}
