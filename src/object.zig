const std = @import("std");
const math = @import("math/math.zig");
const MaterialHandle = @import("material.zig").MaterialSystem.MaterialHandle;

pub const HitRecord = struct {
    p: math.vec.Point3,
    /// Points against the incident ray. This is normalized. Whether this is an inward or outward
    /// normal is stored in the `is_front_face` field.
    normal: math.vec.Vec3,
    t: f64,
    /// Indicates whether the normal is pointing inside the object or outside.
    is_front_face: bool,
    mat: MaterialHandle,

    /// `outward_normal` is assumed to be a unit vector.
    pub fn set_face_normal(self: *HitRecord, ray: *const math.ray.Ray3, outward_normal: math.vec.Vec3) void {
        self.is_front_face = math.vec.dot_vec3(ray.direction, outward_normal) < 0.0;
        if (self.is_front_face) {
            self.normal = outward_normal;
        } else {
            self.normal = -outward_normal;
        }
    }
};

pub const Sphere = struct {
    center: math.vec.Point3,
    radius: f64,
    mat: MaterialHandle,

    fn intersect(self: *const Sphere, ray: *const math.ray.Ray3, ray_t: math.interval.Interval, rec: *HitRecord) bool {
        const oc = ray.origin - self.center;
        const a = math.vec.length_squared_vec3(ray.direction);
        const half_b = math.vec.dot_vec3(oc, ray.direction);
        const c = math.vec.length_squared_vec3(oc) - self.radius * self.radius;

        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0.00001) {
            return false;
        }
        const sqrt_d = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (-half_b - sqrt_d) / a;
        if (!ray_t.surrounds(root)) {
            root = (-half_b + sqrt_d) / a;
            if (!ray_t.surrounds(root)) {
                return false;
            }
        }

        rec.t = root;
        rec.p = ray.at(root);
        const outward_normal = math.vec.div_vec3_scalar((rec.p - self.center), self.radius);
        rec.set_face_normal(ray, outward_normal);
        rec.mat = self.mat;

        return true;
    }
};

pub const ObjectList = struct {
    objects: std.ArrayList(ObjectFactory.ObjectHandle),
    object_factory: *const ObjectFactory,

    pub fn init(allocator: std.mem.Allocator, object_factory: *const ObjectFactory) ObjectList {
        return .{
            .objects = std.ArrayList(ObjectFactory.ObjectHandle).init(allocator),
            .object_factory = object_factory,
        };
    }

    pub fn deinit(self: ObjectList) void {
        self.objects.deinit();
    }

    pub fn add(self: *ObjectList, object: ObjectFactory.ObjectHandle) !void {
        try self.objects.append(object);
    }

    pub fn intersect(self: *const ObjectList, ray: *const math.ray.Ray3, ray_t: math.interval.Interval, rec: *HitRecord) bool {
        var hit_record = HitRecord{
            .t = 0.0,
            .p = math.vec.Point3{ 0.0, 0.0, 0.0 },
            .normal = math.vec.Vec3{ 0.0, 0.0, 0.0 },
            .is_front_face = false,
            .mat = MaterialHandle{ .index = 0 },
        };
        var hit_anything = false;
        var closest_so_far = ray_t.max;

        for (self.objects.items) |object_handle| {
            if (self.object_factory.intersect(object_handle, ray, .{ .min = ray_t.min, .max = closest_so_far }, &hit_record)) {
                hit_anything = true;
                closest_so_far = hit_record.t;
                rec.* = hit_record;
            }
        }

        return hit_anything;
    }
};

pub const ObjectFactory = struct {
    objects: std.ArrayList(Data),
    /// ObjectList needs this.
    allocator: std.mem.Allocator,

    const Data = union(enum) {
        sphere: Sphere,
    };

    pub const ObjectHandle = struct {
        index: usize,
    };

    pub fn init(allocator: std.mem.Allocator) ObjectFactory {
        return .{
            .objects = std.ArrayList(Data).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: ObjectFactory) void {
        self.objects.deinit();
    }

    pub fn create_Sphere(self: *ObjectFactory, center: math.vec.Point3, radius: f64, mat: MaterialHandle) !ObjectHandle {
        const sphere_index = self.objects.items.len;
        const sp = Data{ .sphere = Sphere{ .center = center, .radius = radius, .mat = mat } };
        try self.objects.append(sp);

        return .{ .index = sphere_index };
    }

    pub fn intersect(self: *const ObjectFactory, object_handle: ObjectHandle, ray: *const math.ray.Ray3, ray_t: math.interval.Interval, rec: *HitRecord) bool {
        return switch (self.objects.items[object_handle.index]) {
            Data.sphere => |*sp| sp.intersect(ray, ray_t, rec),
        };
    }
};
