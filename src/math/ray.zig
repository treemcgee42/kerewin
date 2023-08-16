const vec = @import("vec.zig");

pub const Ray3 = struct {
    origin: vec.Point3,
    direction: vec.Vec3,
    time: f64,

    pub fn init_with_time(origin: vec.Point3, direction: vec.Vec3, time: f64) Ray3 {
        return Ray3{
            .origin = origin,
            .direction = direction,
            .time = time,
        };
    }

    pub fn init_without_time(origin: vec.Point3, direction: vec.Vec3) Ray3 {
        return Ray3{
            .origin = origin,
            .direction = direction,
            .time = 0.0,
        };
    }

    pub fn at(self: Ray3, t: f64) vec.Point3 {
        return self.origin + vec.mul_scalar_vec3(t, self.direction);
    }
};
