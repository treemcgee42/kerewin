const std = @import("std");
const math = @import("math/math.zig");
const color = @import("color.zig");
const object = @import("object.zig");
const camera = @import("camera.zig");
const material = @import("material.zig");

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // World
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Materials
    var material_factory = material.MaterialSystem.init(allocator);
    defer material_factory.deinit();

    // Objects
    var object_factory = object.ObjectFactory.init(allocator);
    defer object_factory.deinit();

    var world = object.ObjectList.init(allocator, &object_factory);
    defer world.deinit();

    const ground_material = try material_factory.create_Lambertian(color.Color3{ 0.5, 0.5, 0.5 });
    const sb = try object_factory.create_Sphere(math.vec.Point3{ 0.0, -1000.0, 0.0 }, 1000.0, ground_material);
    try world.add(sb);

    var a: i32 = -11;
    while (a < 11) : (a += 1) {
        var b: i32 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = math.random_f64();
            const center = math.vec.Point3{ @as(f64, @floatFromInt(a)) + 0.9 * math.random_f64(), 0.2, @as(f64, @floatFromInt(b)) + 0.9 * math.random_f64() };

            if (math.vec.length_vec3(center - math.vec.Point3{ 4.0, 0.2, 0.0 }) > 0.9) {
                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = math.random_vec3() * math.random_vec3();
                    const sphere_material = try material_factory.create_Lambertian(albedo);
                    const sphere = try object_factory.create_Sphere(center, 0.2, sphere_material);
                    try world.add(sphere);
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = math.random_vec3_range(0.5, 1.0);
                    const fuzz = math.random_f64_range(0.0, 0.5);
                    const sphere_material = try material_factory.create_Metal(albedo, fuzz);
                    const sphere = try object_factory.create_Sphere(center, 0.2, sphere_material);
                    try world.add(sphere);
                } else {
                    // glass
                    const sphere_material = try material_factory.create_Dielectric(1.5);
                    const sphere = try object_factory.create_Sphere(center, 0.2, sphere_material);
                    try world.add(sphere);
                }
            }
        }
    }

    const material1 = try material_factory.create_Dielectric(1.5);
    const sphere1 = try object_factory.create_Sphere(math.vec.Point3{ 0.0, 1.0, 0.0 }, 1.0, material1);
    try world.add(sphere1);

    const material2 = try material_factory.create_Lambertian(color.Color3{ 0.4, 0.2, 0.1 });
    const sphere2 = try object_factory.create_Sphere(math.vec.Point3{ -4.0, 1.0, 0.0 }, 1.0, material2);
    try world.add(sphere2);

    const material3 = try material_factory.create_Metal(color.Color3{ 0.7, 0.6, 0.5 }, 0.0);
    const sphere3 = try object_factory.create_Sphere(math.vec.Point3{ 4.0, 1.0, 0.0 }, 1.0, material3);
    try world.add(sphere3);

    // Camera
    const cam_init_options: camera.Camera.InitParams = .{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 1200,
        .samples_per_pixel = 10,
        .max_depth = 50,

        .vfov = 20.0,
        .look_from = math.vec.Point3{ 13.0, 2.0, 3.0 },
        .look_at = math.vec.Point3{ 0.0, 0.0, 0.0 },
        .v_up = math.vec.Vec3{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0.6,
        .focus_dist = 10.0,

        .material_system = &material_factory,
    };
    var cam = camera.Camera.init(cam_init_options);
    try cam.render(&world, stdout);

    try bw.flush(); // don't forget to flush!
}
