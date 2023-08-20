const std = @import("std");
const math = @import("math/math.zig");
const Vec3 = math.vec.Vec3;

const point_count: i32 = 256;

pub const Perlin = struct {
    rand_vec: std.ArrayList(Vec3),
    perm_x: std.ArrayList(i32),
    perm_y: std.ArrayList(i32),
    perm_z: std.ArrayList(i32),

    pub fn init(allocator: std.mem.Allocator) !Perlin {
        var to_return: Perlin = undefined;

        to_return.rand_vec = std.ArrayList(Vec3).init(allocator);
        var i: i32 = 0;
        while (i < point_count) : (i += 1) {
            try to_return.rand_vec.append(math.random_vec3_range(-1.0, 1.0));
        }

        to_return.perm_x = try perlin_generate_perm(allocator);
        to_return.perm_y = try perlin_generate_perm(allocator);
        to_return.perm_z = try perlin_generate_perm(allocator);

        return to_return;
    }

    pub fn deinit(self: *Perlin) void {
        self.rand_vec.deinit();
        self.perm_x.deinit();
        self.perm_y.deinit();
        self.perm_z.deinit();
    }

    pub fn noise(self: *const Perlin, p: math.vec.Point3) f64 {
        var u = p[0] - @floor(p[0]);
        var v = p[1] - @floor(p[1]);
        var w = p[2] - @floor(p[2]);
        // Hermitian smoothing.
        u = u * u * (3.0 - 2.0 * u);
        v = v * v * (3.0 - 2.0 * v);
        w = w * w * (3.0 - 2.0 * w);

        const i = @as(i32, @intFromFloat(@floor(p[0])));
        const j = @as(i32, @intFromFloat(@floor(p[1])));
        const k = @as(i32, @intFromFloat(@floor(p[2])));

        var c: [2][2][2]Vec3 = undefined;
        var di: i32 = 0;
        while (di < 2) : (di += 1) {
            var dj: i32 = 0;
            while (dj < 2) : (dj += 1) {
                var dk: i32 = 0;
                while (dk < 2) : (dk += 1) {
                    const idx1: usize = @intCast(self.perm_x.items[@as(u32, @intCast((i + di) & 255))]);
                    const idx2: usize = @intCast(self.perm_y.items[@as(u32, @intCast((j + dj) & 255))]);
                    const idx3: usize = @intCast(self.perm_z.items[@as(u32, @intCast((k + dk) & 255))]);

                    const di_u: usize = @intCast(di);
                    const dj_u: usize = @intCast(dj);
                    const dk_u: usize = @intCast(dk);
                    c[di_u][dj_u][dk_u] = self.rand_vec.items[idx1 ^ idx2 ^ idx3];
                }
            }
        }

        return perlin_interp(c, u, v, w);
    }

    fn perlin_generate_perm(allocator: std.mem.Allocator) !std.ArrayList(i32) {
        var to_return = std.ArrayList(i32).init(allocator);

        var i: i32 = 0;
        while (i < point_count) : (i += 1) {
            try to_return.append(i);
        }

        return to_return;
    }

    fn permute(p: std.ArrayList(i32), n: i32) void {
        var i: i32 = n - 1;
        while (i > 0) : (i -= 1) {
            const target = math.random_i32_range_inclusive(0, i);
            const tmp = p.items[i];
            p.items[i] = p.items[target];
            p.items[target] = tmp;
        }
    }

    fn trilinear_interp(c: [2][2][2]f64, u: f64, v: f64, w: f64) f64 {
        var accum: f64 = 0.0;
        var i: i32 = 0;
        while (i < 2) : (i += 1) {
            var j: i32 = 0;
            while (j < 2) : (j += 1) {
                var k: i32 = 0;
                while (k < 2) : (k += 1) {
                    const factor1 = @as(f64, @floatFromInt(i)) * u + (1.0 - @as(f64, @floatFromInt(i))) * (1.0 - u);
                    const factor2 = @as(f64, @floatFromInt(j)) * v + (1.0 - @as(f64, @floatFromInt(j))) * (1.0 - v);
                    const factor3 = @as(f64, @floatFromInt(k)) * w + (1.0 - @as(f64, @floatFromInt(k))) * (1.0 - w);

                    const i_u: usize = @intCast(i);
                    const j_u: usize = @intCast(j);
                    const k_u: usize = @intCast(k);

                    accum += factor1 * factor2 * factor3 * c[i_u][j_u][k_u];
                }
            }
        }

        return accum;
    }

    fn perlin_interp(c: [2][2][2]Vec3, u: f64, v: f64, w: f64) f64 {
        var uu = u * u * (3.0 - 2.0 * u);
        var vv = v * v * (3.0 - 2.0 * v);
        var ww = w * w * (3.0 - 2.0 * w);

        var accum: f64 = 0.0;
        var i: i32 = 0;
        while (i < 2) : (i += 1) {
            var j: i32 = 0;
            while (j < 2) : (j += 1) {
                var k: i32 = 0;
                while (k < 2) : (k += 1) {
                    const weight_v = Vec3{
                        u - @as(f64, @floatFromInt(i)),
                        v - @as(f64, @floatFromInt(j)),
                        w - @as(f64, @floatFromInt(k)),
                    };
                    const i_u: usize = @intCast(i);
                    const j_u: usize = @intCast(j);
                    const k_u: usize = @intCast(k);

                    const factor1 = @as(f64, @floatFromInt(i)) * uu + (1.0 - @as(f64, @floatFromInt(i))) * (1.0 - uu);
                    const factor2 = @as(f64, @floatFromInt(j)) * vv + (1.0 - @as(f64, @floatFromInt(j))) * (1.0 - vv);
                    const factor3 = @as(f64, @floatFromInt(k)) * ww + (1.0 - @as(f64, @floatFromInt(k))) * (1.0 - ww);

                    accum += factor1 * factor2 * factor3 * math.vec.dot_vec3(c[i_u][j_u][k_u], weight_v);
                }
            }
        }

        return accum;
    }

    pub fn turb(self: *const Perlin, p: Vec3, depth: i32) f64 {
        var accum: f64 = 0.0;
        var temp_p = p;
        var weight: f64 = 1.0;

        var i: i32 = 0;
        while (i < depth) : (i += 1) {
            accum += weight * self.noise(temp_p);
            weight *= 0.5;
            temp_p = math.vec.mul_scalar_vec3(2.0, temp_p);
        }

        return @fabs(accum);
    }
};
