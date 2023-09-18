const std = @import("std");
const math = @import("math/math.zig");
const color = @import("color.zig");
const object = @import("object.zig");
const camera = @import("camera.zig");
const material = @import("material.zig");
const obj = @import("objloader.zig");
const bvh = @import("bvh.zig");
const texture = @import("texture.zig");
const PartialRender = @import("./PartialRender.zig");

fn random_spheres(
    world: *object.ObjectList,
    object_factory: *object.ObjectFactory,
    material_factory: *material.MaterialSystem,
    texture_factory: *texture.TextureSystem,
) !camera.Camera.InitParams {
    const checker_texture = try texture_factory.create_CheckerTexture_colors(
        0.32,
        color.Color3{ 0.2, 0.3, 0.1 },
        color.Color3{ 0.9, 0.9, 0.9 },
    );
    const ground_material = try material_factory.create_Lambertian_texture(checker_texture);
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
                    const sphere_material = try material_factory.create_Lambertian(texture_factory, albedo);
                    const center2 = center + math.vec.Vec3{ 0.0, math.random_f64_range(0.0, 0.5), 0.0 };
                    const sphere = try object_factory.create_Sphere_moving(center, center2, 0.2, sphere_material);
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

    const material2 = try material_factory.create_Lambertian(texture_factory, color.Color3{ 0.4, 0.2, 0.1 });
    const sphere2 = try object_factory.create_Sphere(math.vec.Point3{ -4.0, 1.0, 0.0 }, 1.0, material2);
    try world.add(sphere2);

    const material3 = try material_factory.create_Metal(color.Color3{ 0.7, 0.6, 0.5 }, 0.0);
    const sphere3 = try object_factory.create_Sphere(math.vec.Point3{ 4.0, 1.0, 0.0 }, 1.0, material3);
    try world.add(sphere3);

    return camera.Camera.InitParams{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 10,
        .max_depth = 50,

        .vfov = 20.0,
        .look_from = math.vec.Point3{ 13.0, 2.0, 3.0 },
        .look_at = math.vec.Point3{ 0.0, 0.0, 0.0 },
        .v_up = math.vec.Vec3{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0.6,
        .focus_dist = 10.0,

        .material_system = material_factory,
        .texture_system = texture_factory,
    };
}

fn two_spheres(
    world: *object.ObjectList,
    object_factory: *object.ObjectFactory,
    material_factory: *material.MaterialSystem,
    texture_factory: *texture.TextureSystem,
) !camera.Camera.InitParams {
    const checker = try texture_factory.create_CheckerTexture_colors(
        0.8,
        color.Color3{ 0.2, 0.3, 0.1 },
        color.Color3{ 0.9, 0.9, 0.9 },
    );
    const mat = try material_factory.create_Lambertian_texture(checker);

    const s1 = try object_factory.create_Sphere(math.vec.Point3{ 0.0, -10.0, 0.0 }, 10.0, mat);
    try world.add(s1);
    const s2 = try object_factory.create_Sphere(math.vec.Point3{ 0.0, 10.0, 0.0 }, 10.0, mat);
    try world.add(s2);

    return camera.Camera.InitParams{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 10,
        .max_depth = 50,

        .vfov = 20.0,
        .look_from = math.vec.Point3{ 13.0, 2.0, 3.0 },
        .look_at = math.vec.Point3{ 0.0, 0.0, 0.0 },
        .v_up = math.vec.Vec3{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0,

        .material_system = material_factory,
        .texture_system = texture_factory,
    };
}

fn earth(
    world: *object.ObjectList,
    object_factory: *object.ObjectFactory,
    material_factory: *material.MaterialSystem,
    texture_factory: *texture.TextureSystem,
    allocator: std.mem.Allocator,
) !camera.Camera.InitParams {
    const earth_texture = try texture_factory.create_ImageTexture_filename("images/earthmap.png", allocator);
    const earth_surface = try material_factory.create_Lambertian_texture(earth_texture);
    const globe = try object_factory.create_Sphere(math.vec.Point3{ 0.0, 0.0, 0.0 }, 2.0, earth_surface);
    try world.add(globe);

    return camera.Camera.InitParams{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,

        .vfov = 20.0,
        .look_from = math.vec.Point3{ 0.0, 0.0, 12.0 },
        .look_at = math.vec.Point3{ 0.0, 0.0, 0.0 },
        .v_up = math.vec.Vec3{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0,

        .material_system = material_factory,
        .texture_system = texture_factory,
    };
}

fn two_perlin_spheres(
    world: *object.ObjectList,
    object_factory: *object.ObjectFactory,
    material_factory: *material.MaterialSystem,
    texture_factory: *texture.TextureSystem,
    allocator: std.mem.Allocator,
) !camera.Camera.InitParams {
    const pertext = try texture_factory.create_NoiseTexture_scale(allocator, 4.0);
    const mat = try material_factory.create_Lambertian_texture(pertext);

    const s1 = try object_factory.create_Sphere(math.vec.Point3{ 0.0, -1000.0, 0.0 }, 1000.0, mat);
    try world.add(s1);
    const s2 = try object_factory.create_Sphere(math.vec.Point3{ 0.0, 2.0, 0.0 }, 2.0, mat);
    try world.add(s2);

    return .{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 10,
        .max_depth = 50,

        .vfov = 20.0,
        .look_from = math.vec.Point3{ 13.0, 2.0, 3.0 },
        .look_at = math.vec.Point3{ 0.0, 0.0, 0.0 },
        .v_up = math.vec.Vec3{ 0.0, 1.0, 0.0 },

        .defocus_angle = 0,

        .material_system = material_factory,
        .texture_system = texture_factory,
    };
}

pub fn main_old(partial_render: *PartialRender, allocator: std.mem.Allocator, render_complete: *bool) !void {
    var timer = try std.time.Timer.start();

    // World

    // Materials
    var material_factory = material.MaterialSystem.init(allocator);
    defer material_factory.deinit();

    // Textures
    var texture_factory = texture.TextureSystem.init(allocator);
    defer texture_factory.deinit();

    // Objects
    var object_factory = object.ObjectFactory.init(allocator);
    defer object_factory.deinit();

    var world = object.ObjectList.init(allocator, &object_factory);
    // defer world.deinit();

    const cam_init_options = switch (3) {
        1 => try random_spheres(&world, &object_factory, &material_factory, &texture_factory),
        2 => try two_spheres(&world, &object_factory, &material_factory, &texture_factory),
        3 => try earth(&world, &object_factory, &material_factory, &texture_factory, allocator),
        4 => try two_perlin_spheres(&world, &object_factory, &material_factory, &texture_factory, allocator),
        else => unreachable,
    };

    std.debug.print("{} objects\n", .{world.objects.items.len});

    var world_bvh = object.ObjectList.init(allocator, &object_factory);
    var bvh_node = try object_factory.create_BvhNode_with_list(&world);
    try world_bvh.add(bvh_node);
    world.deinit();
    defer world_bvh.deinit();

    // Camera
    var cam = camera.Camera.init(cam_init_options);
    try cam.render(&world_bvh, partial_render);

    const total_time = @as(f64, @floatFromInt(timer.read())) / 1000000000.0;
    std.debug.print("\nTotal time: {d:.2} seconds\n", .{total_time});
    render_complete.* = true;
}

const raylib = @import("c.zig").raylib;
const raygui = @import("c.zig").raygui;

pub const Bounds = struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

pub fn preview_region(bounds: Bounds, tex: raylib.Texture2D) void {
    var x = bounds.x;
    var y = bounds.y;

    var scale: f32 = 1.0;
    const texture_width = tex.width;
    if (texture_width > bounds.width) {
        scale = @as(f32, @floatFromInt(bounds.width)) / @as(f32, @floatFromInt(texture_width));
    } else {
        // Center the texture within the bounds.
        const texture_height = tex.height;
        x += @intFromFloat(@floor(@as(f32, @floatFromInt(bounds.width - texture_width)) / 2.0));
        y += @intFromFloat(@floor(@as(f32, @floatFromInt(bounds.height - texture_height)) / 2.0));
    }

    raylib.DrawTextureEx(tex, raylib.Vector2{ .x = @as(f32, @floatFromInt(x)), .y = @as(f32, @floatFromInt(y)) }, 0.0, scale, raylib.WHITE);
}

fn get_status_bar_text(render_complete: bool) [*c]const u8 {
    if (render_complete) {
        return "Render complete.";
    } else {
        return "Rendering...";
    }
}

pub fn main() !void {
    var window_width: c_int = undefined;
    var window_height: c_int = undefined;
    const screen_width = raylib.GetScreenWidth();
    if (screen_width > 1600) {
        window_width = 1600;
        window_height = 900;
    } else {
        window_width = 1280;
        window_height = 720;
    }
    raylib.InitWindow(window_width, window_height, "kerewin");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var render_complete = false;
    var partial_render = try PartialRender.init(allocator, 400, 225);
    const render_thread = try std.Thread.spawn(.{}, main_old, .{ &partial_render, allocator, &render_complete });

    var final_preview = false;
    var preview_image = partial_render.load_raylib_image();
    var preview_texture = raylib.LoadTextureFromImage(preview_image);

    var preview_timer = try std.time.Timer.start();

    while (!raylib.WindowShouldClose()) {
        // Preview updates every 2 seconds.
        if (partial_render.sync.should_read) {
            if (!final_preview and preview_timer.read() > 1_000_000_000) {
                std.debug.print("update preview\n", .{});
                partial_render.update_raylib_image(&preview_image);
                const colors = raylib.LoadImageColors(preview_image);
                raylib.UpdateTexture(preview_texture, colors);
                raylib.UnloadImageColors(colors);

                if (render_complete) {
                    final_preview = true;
                }

                preview_timer.reset();
            } else {
                partial_render.sync.should_read = false;
            }
        }

        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.RAYWHITE);

        // Preview region.
        preview_region(
            .{
                .x = 0,
                .y = 0,
                .width = raylib.GetScreenWidth(),
                .height = raylib.GetScreenHeight() - 20,
            },
            preview_texture,
        );

        _ = raygui.GuiStatusBar(
            raygui.Rectangle{
                .x = 0,
                .y = @as(f32, @floatFromInt(raylib.GetScreenHeight())) - 20,
                .width = @as(f32, @floatFromInt(raylib.GetScreenWidth())),
                .height = 20,
            },
            get_status_bar_text(render_complete),
        );

        _ = raygui.GuiProgressBar(
            raygui.Rectangle{
                .x = @as(f32, @floatFromInt(raylib.GetScreenWidth())) - 300,
                .y = @as(f32, @floatFromInt(raylib.GetScreenHeight())) - 17,
                .width = 250,
                .height = 14,
            },
            "",
            "",
            &partial_render.current_progress,
            0.0,
            partial_render.max_progress,
        );

        raylib.EndDrawing();
    }

    partial_render.deinit(allocator);
    raylib.UnloadImage(preview_image);
    raylib.UnloadTexture(preview_texture);
    render_thread.join();

    raylib.CloseWindow();
}
