pub const vec3_precision = f64;

pub const Vec3 = @Vector(3, vec3_precision);
pub const Point3 = @Vector(3, vec3_precision);

// Vector utility functions

pub fn mul_scalar_vec3(s: vec3_precision, v: Vec3) Vec3 {
    return @as(Vec3, @splat(s)) * v;
}

pub fn div_vec3_scalar(v: Vec3, s: vec3_precision) Vec3 {
    return v / @as(Vec3, @splat(s));
}

pub fn dot_vec3(v1: Vec3, v2: Vec3) vec3_precision {
    const tmp = v1 * v2;
    return tmp[0] + tmp[1] + tmp[2];
}

pub fn length_squared_vec3(v: Vec3) vec3_precision {
    return dot_vec3(v, v);
}

pub fn cross_vec3(v1: Vec3, v2: Vec3) Vec3 {
    return Vec3{ v1[1] * v2[2] - v1[2] * v2[1], v1[2] * v2[0] - v1[0] * v2[2], v1[0] * v2[1] - v1[1] * v2[0] };
}

pub fn length_vec3(v: Vec3) vec3_precision {
    return @sqrt(dot_vec3(v, v));
}

pub fn normalize_vec3(v: Vec3) Vec3 {
    const len = length_vec3(v);
    return div_vec3_scalar(v, len);
}

/// Returns true if the vector is close to zero in all dimensions.
pub fn near_zero_vec3(v: Vec3) bool {
    const s = 1e-8;
    return v[0] < s and v[0] > -s and v[1] < s and v[1] > -s and v[2] < s and v[2] > -s;
}

pub fn reflect_vec3(v: Vec3, n: Vec3) Vec3 {
    return v - mul_scalar_vec3(2.0 * dot_vec3(v, n), n);
}

pub fn refract_vec3(uv: Vec3, n: Vec3, etai_over_etat: vec3_precision) Vec3 {
    const cos_theta = @min(1.0, dot_vec3(-uv, n));
    const r_out_perp = mul_scalar_vec3(etai_over_etat, uv + mul_scalar_vec3(cos_theta, n));
    const r_out_parallel = mul_scalar_vec3(-@sqrt(@fabs(1.0 - length_squared_vec3(r_out_perp))), n);
    return r_out_parallel + r_out_perp;
}
