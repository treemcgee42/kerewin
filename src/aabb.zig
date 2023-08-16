const math = @import("math/math.zig");
const std = @import("std");

pub const Aabb = struct {
    x: math.interval.Interval,
    y: math.interval.Interval,
    z: math.interval.Interval,

    // The default AABB is empty, since intervals are empty by default.
    pub fn init_default() Aabb {
        return Aabb{
            .x = math.interval.Interval.init_empty(),
            .y = math.interval.Interval.init_empty(),
            .z = math.interval.Interval.init_empty(),
        };
    }

    pub fn init_with_intervals(ix: math.interval.Interval, iy: math.interval.Interval, iz: math.interval.Interval) Aabb {
        return Aabb{
            .x = ix,
            .y = iy,
            .z = iz,
        };
    }

    pub fn init_with_aabbs(box0: *const Aabb, box1: *const Aabb) Aabb {
        return Aabb{
            .x = math.interval.Interval.init_with_intervals(box0.x, box1.x),
            .y = math.interval.Interval.init_with_intervals(box0.y, box1.y),
            .z = math.interval.Interval.init_with_intervals(box0.z, box1.z),
        };
    }

    // Treate the two points a and b as extrema for the bounding box, so we don't require a
    // particular minimum/maximum coordinate order.
    pub fn init_with_points(a: math.vec.Point3, b: math.vec.Point3) Aabb {
        return Aabb{
            .x = math.interval.Interval{ .min = @min(a[0], b[0]), .max = @max(a[0], b[0]) },
            .y = math.interval.Interval{ .min = @min(a[1], b[1]), .max = @max(a[1], b[1]) },
            .z = math.interval.Interval{ .min = @min(a[2], b[2]), .max = @max(a[2], b[2]) },
        };
    }

    pub fn axis(self: *const Aabb, n: i32) math.interval.Interval {
        switch (n) {
            1 => return self.y,
            2 => return self.z,
            else => return self.x,
        }
    }

    pub fn hit(self: *const Aabb, r: *const math.ray.Ray3, ray_t: math.interval.Interval) bool {
        var rt_min = ray_t.min;
        var rt_max = ray_t.max;

        var a: i32 = 0;
        while (a < 3) : (a += 1) {
            const inv_d: f64 = 1.0 / r.direction[@intCast(a)];
            const orig: f64 = r.origin[@intCast(a)];

            var t0: f64 = (self.axis(a).min - orig) * inv_d;
            var t1: f64 = (self.axis(a).max - orig) * inv_d;

            if (inv_d < 0.0) {
                std.mem.swap(f64, &t0, &t1);
            }

            if (t0 > rt_min) {
                rt_min = t0;
            }
            if (t1 < rt_max) {
                rt_max = t1;
            }

            if (rt_max <= rt_min) {
                return false;
            }
        }

        return true;
    }
};
