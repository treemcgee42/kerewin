const std = @import("std");
const math = @import("math/math.zig");
const object = @import("object.zig");
const aabb = @import("aabb.zig");

pub const BvhNode = struct {
    factory: *const object.ObjectFactory,
    left: object.ObjectFactory.ObjectHandle,
    right: object.ObjectFactory.ObjectHandle,
    bbox: aabb.Aabb,

    pub fn init_with_list(factory: *object.ObjectFactory, list: *const object.ObjectList) anyerror!BvhNode {
        return BvhNode.init_with_start_end(factory, &list.objects, 0, list.objects.items.len);
    }

    pub fn init_with_start_end(
        factory: *object.ObjectFactory,
        src_objects: *const std.ArrayList(object.ObjectFactory.ObjectHandle),
        start: usize,
        end: usize,
    ) anyerror!BvhNode {
        var left = object.ObjectFactory.ObjectHandle{ .index = 0 };
        var right = object.ObjectFactory.ObjectHandle{ .index = 0 };

        var objects = try src_objects.clone();
        defer objects.deinit();

        var axis = math.random_i32_range_inclusive(0, 2);
        const comparator = switch (axis) {
            0 => &box_x_compare,
            1 => &box_y_compare,
            else => &box_z_compare,
        };

        const object_span: usize = end - start;
        switch (object_span) {
            1 => {
                // std.debug.print("1... ", .{});
                left = objects.items[start];
                right = objects.items[start];
            },
            2 => {
                // std.debug.print("2... ", .{});
                if (comparator(factory, objects.items[start], objects.items[start + 1])) {
                    left = objects.items[start];
                    right = objects.items[start + 1];
                } else {
                    left = objects.items[start + 1];
                    right = objects.items[start];
                }
            },
            else => {
                // std.debug.print("before sorting: {}", .{objects.items[start]});
                switch (axis) {
                    0 => std.mem.sort(object.ObjectFactory.ObjectHandle, objects.items[start..end], factory, box_x_compare),
                    1 => std.mem.sort(object.ObjectFactory.ObjectHandle, objects.items[start..end], factory, box_y_compare),
                    else => std.mem.sort(object.ObjectFactory.ObjectHandle, objects.items[start..end], factory, box_z_compare),
                }
                // std.debug.print("after sorting: {}", .{objects.items[start]});
                // std.mem.sort(object.ObjectFactory.ObjectHandle, objects.items[start..end], factory, comparator);
                // std.sort.insertion(object.ObjectFactory.ObjectHandle, objects.items[start..end], factory, comparator);

                const mid = start + (object_span / 2);
                left = try factory.create_BvhNode_with_start_end(&objects, start, mid);
                right = try factory.create_BvhNode_with_start_end(&objects, mid, end);
                // std.debug.print("else... ", .{});
            },
        }

        // std.debug.print("left {} right {}\n", .{ left.index, right.index });

        const bbox = aabb.Aabb.init_with_aabbs(&factory.bounding_box(left), &factory.bounding_box(right));

        return BvhNode{
            .factory = factory,
            .left = left,
            .right = right,
            .bbox = bbox,
        };
    }

    pub fn intersect(self: *const BvhNode, ray: *const math.ray.Ray3, ray_t: math.interval.Interval, hit: *object.HitRecord) bool {
        // std.debug.print("intersecting for bbox ({}, {}, {}) - ({}, {}, {})\n", .{ self.bbox.x.min, self.bbox.y.min, self.bbox.z.min, self.bbox.x.max, self.bbox.y.max, self.bbox.z.max });

        if (!self.bbox.hit(ray, ray_t)) {
            return false;
        }

        const hit_left = self.factory.intersect(self.left, ray, ray_t, hit);
        var upper_endpoint = ray_t.max;
        if (hit_left) {
            upper_endpoint = hit.t;
        }
        const hit_right = self.factory.intersect(
            self.right,
            ray,
            math.interval.Interval{ .min = ray_t.min, .max = upper_endpoint },
            hit,
        );

        return hit_left or hit_right;
    }

    pub fn bounding_box(self: *const BvhNode) aabb.Aabb {
        return self.bbox;
    }
};

fn box_compare(
    factory: *const object.ObjectFactory,
    a: object.ObjectFactory.ObjectHandle,
    b: object.ObjectFactory.ObjectHandle,
    axis: i32,
) bool {
    const box_a = factory.bounding_box(a);
    const box_b = factory.bounding_box(b);
    return box_a.axis(axis).min < box_b.axis(axis).min;
}

fn box_x_compare(
    factory: *const object.ObjectFactory,
    a: object.ObjectFactory.ObjectHandle,
    b: object.ObjectFactory.ObjectHandle,
) bool {
    return box_compare(factory, a, b, 0);
}

fn box_y_compare(
    factory: *const object.ObjectFactory,
    a: object.ObjectFactory.ObjectHandle,
    b: object.ObjectFactory.ObjectHandle,
) bool {
    return box_compare(factory, a, b, 1);
}

fn box_z_compare(
    factory: *const object.ObjectFactory,
    a: object.ObjectFactory.ObjectHandle,
    b: object.ObjectFactory.ObjectHandle,
) bool {
    return box_compare(factory, a, b, 2);
}
