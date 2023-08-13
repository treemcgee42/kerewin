const vec = @import("vec.zig");

pub const Ray3 = struct {
    origin: vec.Point3,
    direction: vec.Vec3,

    pub fn at(self: Ray3, t: f64) vec.Point3 {
        return self.origin + vec.mul_scalar_vec3(t, self.direction);
    }
};
