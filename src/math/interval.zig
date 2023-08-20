const math = @import("math.zig");

pub const Interval = struct {
    min: f64,
    max: f64,

    pub fn init_with_floats(min: f64, max: f64) Interval {
        return Interval{
            .min = min,
            .max = max,
        };
    }

    pub fn init_with_intervals(a: Interval, b: Interval) Interval {
        return Interval{
            .min = @min(a.min, b.min),
            .max = @max(a.max, b.max),
        };
    }

    pub fn init_empty() Interval {
        return Interval{
            .min = math.infinity,
            .max = -math.infinity,
        };
    }

    pub fn contains(self: Interval, x: f64) bool {
        return x >= self.min and x <= self.max;
    }

    pub fn surrounds(self: Interval, x: f64) bool {
        return x > self.min and x < self.max;
    }

    pub fn clamp(self: Interval, x: f64) f64 {
        return @min(@max(x, self.min), self.max);
    }

    pub fn size(self: Interval) f64 {
        return self.max - self.min;
    }

    pub fn expand(self: Interval, delta: f64) Interval {
        const padding = delta / 2.0;

        return Interval{
            .min = self.min - padding,
            .max = self.max + padding,
        };
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
