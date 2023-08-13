const math = @import("math.zig");

pub const Interval = struct {
    min: f64 = -math.infinity,
    max: f64 = math.infinity,

    pub fn contains(self: Interval, x: f64) bool {
        return x >= self.min and x <= self.max;
    }

    pub fn surrounds(self: Interval, x: f64) bool {
        return x > self.min and x < self.max;
    }

    pub fn clamp(self: Interval, x: f64) f64 {
        return @min(@max(x, self.min), self.max);
    }
};

const empty_interval = struct {
    min: f64 = math.infinity,
    max: f64 = -math.infinity,
};

const universe_interval = struct {
    min: f64 = -math.infinity,
    max: f64 = math.infinity,
};
