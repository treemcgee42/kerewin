const std = @import("std");
const math = @import("math/math.zig");

pub const Color3 = math.vec.Vec3;

inline fn linear_to_gamme(linear_component: f64) f64 {
    return @sqrt(linear_component);
}

const intensity: math.interval.Interval = .{ .min = 0.0, .max = 0.999 };

pub fn write_color3(color: Color3, samples_per_pixel: u32, out: anytype) !void {
    var r = color[0];
    var g = color[1];
    var b = color[2];

    const scale: f64 = 1.0 / @as(f64, @floatFromInt(samples_per_pixel));
    r *= scale;
    g *= scale;
    b *= scale;

    r = linear_to_gamme(r);
    g = linear_to_gamme(g);
    b = linear_to_gamme(b);

    const ir: i32 = @intFromFloat(256.0 * intensity.clamp(r));
    const ig: i32 = @intFromFloat(256.0 * intensity.clamp(g));
    const ib: i32 = @intFromFloat(256.0 * intensity.clamp(b));

    try out.print("{} {} {}\n", .{ ir, ig, ib });
}
