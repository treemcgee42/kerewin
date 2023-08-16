const std = @import("std");
const math = @import("math/math.zig");
const MaterialHandle = @import("material.zig").MaterialSystem.MaterialHandle;
const aabb = @import("aabb.zig");
const bvh = @import("bvh.zig");

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
    // Center at t=0.
    center1: math.vec.Point3,
    radius: f64,
    mat: MaterialHandle,
    is_moving: bool,
    center_vec: math.vec.Vec3,
    bbox: aabb.Aabb,

    fn init_stationary(center: math.vec.Point3, radius: f64, mat: MaterialHandle) Sphere {
        const rvec = math.vec.Vec3{ radius, radius, radius };

        return .{
            .center1 = center,
            .radius = radius,
            .mat = mat,
            .is_moving = false,
            .center_vec = math.vec.Vec3{ 0.0, 0.0, 0.0 },
            .bbox = aabb.Aabb.init_with_points(center - rvec, center + rvec),
        };
    }

    fn init_moving(center1: math.vec.Point3, center2: math.vec.Point3, radius: f64, mat: MaterialHandle) Sphere {
        const rvec = math.vec.Vec3{ radius, radius, radius };
        const box1 = aabb.Aabb.init_with_points(center1 - rvec, center1 + rvec);
        const box2 = aabb.Aabb.init_with_points(center2 - rvec, center2 + rvec);
        const bbox = aabb.Aabb.init_with_aabbs(&box1, &box2);

        return .{
            .center1 = center1,
            .radius = radius,
            .mat = mat,
            .is_moving = true,
            .center_vec = center2 - center1,
            .bbox = bbox,
        };
    }

    pub fn get_center(self: *const Sphere, t: f64) math.vec.Point3 {
        return self.center1 + math.vec.mul_scalar_vec3(t, self.center_vec);
    }

    fn intersect(self: *const Sphere, ray: *const math.ray.Ray3, ray_t: math.interval.Interval, rec: *HitRecord) bool {
        var center = self.center1;
        if (self.is_moving) {
            center = self.get_center(ray.time);
        }
        const oc = ray.origin - center;
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
        const outward_normal = math.vec.div_vec3_scalar((rec.p - center), self.radius);
        rec.set_face_normal(ray, outward_normal);
        rec.mat = self.mat;

        return true;
    }

    fn bounding_box(self: *const Sphere) aabb.Aabb {
        return self.bbox;
    }
};

pub const ObjectList = struct {
    objects: std.ArrayList(ObjectFactory.ObjectHandle),
    object_factory: *const ObjectFactory,
    bbox: aabb.Aabb,

    pub fn init(allocator: std.mem.Allocator, object_factory: *const ObjectFactory) ObjectList {
        return .{
            .objects = std.ArrayList(ObjectFactory.ObjectHandle).init(allocator),
            .object_factory = object_factory,
            .bbox = aabb.Aabb.init_default(),
        };
    }

    pub fn deinit(self: ObjectList) void {
        self.objects.deinit();
    }

    pub fn add(self: *ObjectList, object: ObjectFactory.ObjectHandle) !void {
        try self.objects.append(object);
        const new_bbox = aabb.Aabb.init_with_aabbs(&self.bbox, &self.object_factory.bounding_box(object));
        self.bbox = new_bbox;
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

    pub fn bounding_box(self: *const ObjectList) aabb.Aabb {
        return self.bbox;
    }
};

pub const ObjectFactory = struct {
    objects: std.ArrayList(Data),
    /// ObjectList needs this.
    allocator: std.mem.Allocator,

    pub const Data = union(enum) {
        sphere: Sphere,
        bvh_node: bvh.BvhNode,
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
        const sp = Data{ .sphere = Sphere.init_stationary(center, radius, mat) };
        try self.objects.append(sp);

        return .{ .index = sphere_index };
    }

    pub fn create_Sphere_moving(self: *ObjectFactory, center1: math.vec.Point3, center2: math.vec.Point3, radius: f64, mat: MaterialHandle) !ObjectHandle {
        const sphere_index = self.objects.items.len;
        const sp = Data{ .sphere = Sphere.init_moving(center1, center2, radius, mat) };
        try self.objects.append(sp);

        return .{ .index = sphere_index };
    }

    pub fn create_BvhNode_with_list(self: *ObjectFactory, list: *const ObjectList) !ObjectHandle {
        const bvh_node = try bvh.BvhNode.init_with_list(self, list);
        const bvh_node_index = self.objects.items.len;
        const bvh_data = Data{ .bvh_node = bvh_node };
        try self.objects.append(bvh_data);

        return .{ .index = bvh_node_index };
    }

    pub fn create_BvhNode_with_start_end(
        self: *ObjectFactory,
        src_objects: *const std.ArrayList(ObjectFactory.ObjectHandle),
        start: usize,
        end: usize,
    ) !ObjectHandle {
        const bvh_node = try bvh.BvhNode.init_with_start_end(self, src_objects, start, end);
        const bvh_node_index = self.objects.items.len;
        const bvh_data = Data{ .bvh_node = bvh_node };
        try self.objects.append(bvh_data);

        return .{ .index = bvh_node_index };
    }

    pub fn intersect(self: *const ObjectFactory, object_handle: ObjectHandle, ray: *const math.ray.Ray3, ray_t: math.interval.Interval, rec: *HitRecord) bool {
        //std.debug.print("Intersecting index {}", .{object_handle.index});
        //        switch (self.objects.items[object_handle.index]) {
        //            Data.sphere => {},
        //            Data.bvh_node => {
        //                std.debug.print("Intercting bvh node at index {}", .{object_handle.index});
        //            },
        //        }

        return switch (self.objects.items[object_handle.index]) {
            Data.sphere => |*sp| sp.intersect(ray, ray_t, rec),
            Data.bvh_node => |*bvh_node| bvh_node.intersect(ray, ray_t, rec),
        };
    }

    pub fn bounding_box(self: *const ObjectFactory, object_handle: ObjectHandle) aabb.Aabb {
        return switch (self.objects.items[object_handle.index]) {
            Data.sphere => |*sp| sp.bounding_box(),
            Data.bvh_node => |*bvh_node| bvh_node.bounding_box(),
        };
    }
};
