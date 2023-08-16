const std = @import("std");
const Vec3 = @import("math/math.zig").vec.Vec3;

pub const VertexTextureNormal = struct { usize, ?usize, ?usize };

pub const Face = [3]VertexTextureNormal;

pub const LoadedObj = struct {
    vertices: std.ArrayList(Vec3),
    normals: std.ArrayList(Vec3),
    texture_coords: std.ArrayList(Vec3),
    faces: std.ArrayList(Face),

    pub fn deinit(self: *LoadedObj) void {
        self.vertices.deinit();
        self.normals.deinit();
        self.texture_coords.deinit();
        self.faces.deinit();
    }
};

/// Consumes all ignored characters, returning a slice of `input` which starts
/// at the first non-ignored character.
fn eat_ignored(input: []u8) []u8 {
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];

        if (c == '#') {
            // Skip the rest of the line. We indicate this by returning an
            // empty slice.
            return input[i..i];
        }

        if (c == ' ' or c == '\t') {
            continue;
        }

        return input[i..];
    }

    // If we reached this point, then the entire input is ignored characters.
    // We indicate this by returning an empty slice.
    return input[0..0];
}

/// Returns `true` if `c` is an ignored character.
fn is_ignored(c: u8) bool {
    return c == ' ' or c == '\t' or c == '#';
}

const StartingToken = enum {
    Vertex,
    Normal,
    TextureCoord,
    Face,
};

pub const TokenParseError = error{
    InvalidToken,
    InvalidVertex,
    InvalidNormal,
    InvalidTextureCoord,
    InvalidFace,
};

const TokenParseResult = struct {
    token: StartingToken,
    rest: []u8,
};

/// Eats the first token of the line, returning the token and the rest of the
/// line.
fn eat_starting_token(input: []u8) (TokenParseError)!TokenParseResult {
    // Read input until an ignored character is found.
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];

        if (is_ignored(c)) {
            break;
        }
    }

    if (input.len < i + 1) {
        return TokenParseError.InvalidToken;
    }

    const working_slice = input[0..i];

    if (working_slice.len == 0) {
        return TokenParseError.InvalidToken;
    }

    // Match for 'v', 'vn', 'vt', or 'f'.
    if (std.mem.eql(u8, working_slice, "v")) {
        return .{ .token = StartingToken.Vertex, .rest = input[i..] };
    } else if (std.mem.eql(u8, working_slice, "vn")) {
        return .{ .token = StartingToken.Normal, .rest = input[i..] };
    } else if (std.mem.eql(u8, working_slice, "vt")) {
        return .{ .token = StartingToken.TextureCoord, .rest = input[i..] };
    } else if (std.mem.eql(u8, working_slice, "f")) {
        return .{ .token = StartingToken.Face, .rest = input[i..] };
    } else {
        return TokenParseError.InvalidToken;
    }
}

const ParseFloatResult = struct {
    float: f64,
    rest: []u8,
};

/// Parses a floating point number, returning the number and the rest of the
/// line.
fn parse_float(input: []u8) (TokenParseError)!ParseFloatResult {
    var working_slice = eat_ignored(input);

    // Get a slice of the bytes from now until the next ignored character.
    var i: usize = 0;
    while (i < working_slice.len) : (i += 1) {
        const c = working_slice[i];
        if (is_ignored(c)) {
            break;
        }
    }

    if (i == 0) {
        std.debug.print("First character is an ignored character in '{s}'", .{working_slice});
        return TokenParseError.InvalidVertex;
    }

    const float_slice = working_slice[0..i];
    const res = std.fmt.parseFloat(f64, float_slice) catch {
        std.debug.print("Failed to parse float from '{s}'", .{float_slice});
        return TokenParseError.InvalidVertex;
    };
    return .{ .float = res, .rest = working_slice[i..] };
}

/// Assumes the starting token is a vertex, and parses the rest of the line.
fn eat_vertex(input: []u8) (TokenParseError)!Vec3 {
    var working_slice = eat_ignored(input);

    const x_res = try parse_float(working_slice);
    working_slice = eat_ignored(x_res.rest);

    const y_res = try parse_float(working_slice);
    working_slice = eat_ignored(y_res.rest);

    const z_res = try parse_float(working_slice);
    working_slice = eat_ignored(z_res.rest);

    // If not end of line, try to get the w component.
    if (working_slice.len == 0) {
        return Vec3{ x_res.float, y_res.float, z_res.float };
    }

    const w_res = try parse_float(working_slice);
    working_slice = eat_ignored(w_res.rest);

    if (working_slice.len != 0) {
        std.debug.print("Remaining slice: {s}", .{working_slice});
        return TokenParseError.InvalidVertex;
    }

    return Vec3{ x_res.float / w_res.float, y_res.float / w_res.float, z_res.float / w_res.float };
}

/// Assumes the starting token is a normal, and parses the rest of the line.
fn eat_normal(input: []u8) (TokenParseError)!Vec3 {
    var working_slice = eat_ignored(input);

    const x_res = try parse_float(working_slice);
    working_slice = eat_ignored(x_res.rest);

    const y_res = try parse_float(working_slice);
    working_slice = eat_ignored(y_res.rest);

    const z_res = try parse_float(working_slice);
    working_slice = eat_ignored(z_res.rest);

    if (working_slice.len != 0) {
        return TokenParseError.InvalidNormal;
    }

    return Vec3{ x_res.float, y_res.float, z_res.float };
}

/// Assumes the starting token is a texture coordinate, and parses the rest of
/// the line.
fn eat_texture_coord(input: []u8) (TokenParseError)!Vec3 {
    var working_slice = eat_ignored(input);

    const u_res = try parse_float(working_slice);
    working_slice = eat_ignored(u_res.rest);

    const v_res = try parse_float(working_slice);
    working_slice = eat_ignored(v_res.rest);

    // If not end of line, try to get the z component.
    if (working_slice.len == 0) {
        return Vec3{ u_res.float, v_res.float, 1.0 };
    }

    const w_res = try parse_float(working_slice);
    working_slice = eat_ignored(w_res.rest);

    if (working_slice.len != 0) {
        return TokenParseError.InvalidTextureCoord;
    }

    return Vec3{ u_res.float, v_res.float, w_res.float };
}

const ParseFaceTripleResult = struct {
    vtn: VertexTextureNormal,
    rest: []u8,
};

/// Parses a triple of ints X/Y/Z, where Y and Z are optional.
fn parse_face_triple(input: []u8) (TokenParseError)!ParseFaceTripleResult {
    var working_slice = eat_ignored(input);
    var c: u8 = 'x';

    // The character after the first integer can be either a space or a slash.
    // If it's a slash, we have to parse more integers. If it's a space, we're
    // done.
    var i: usize = 0;
    var end_of_input = false;
    while (true) {
        if (i >= working_slice.len) {
            end_of_input = true;
            break;
        }

        c = working_slice[i];

        if (c == '/' or c == ' ') {
            break;
        }

        i += 1;
    }

    const first_int_slice = working_slice[0..i];
    const first_int_res = std.fmt.parseInt(usize, first_int_slice, 10) catch {
        std.debug.print("Failed to parse first int from '{s}'\n", .{first_int_slice});
        return TokenParseError.InvalidFace;
    };

    // We know the length of `working_slice` is at least i+1. If it is exactly i+1,
    // then we're done.
    if (c == ' ' or working_slice.len == i + 1 or end_of_input) {
        return .{ .vtn = .{ first_int_res, null, null }, .rest = working_slice[i..] };
    }

    working_slice = working_slice[i + 1 ..];

    // If the next character is a slash, we have to parse more integers and this integer
    // is null. If the next character is a space, we're done.
    var second_int_res: ?usize = null;
    if (working_slice[0] == ' ') {
        return .{ .vtn = .{ first_int_res, null, null }, .rest = working_slice };
    } else if (working_slice[0] == '/') {
        working_slice = eat_ignored(working_slice[1..]);
    } else {
        i = 0;
        while (i < working_slice.len) : (i += 1) {
            c = working_slice[i];

            if (c == '/' or c == ' ') {
                break;
            }
        }

        const second_int_slice = working_slice[0..i];
        if (second_int_slice.len != 0) {
            second_int_res = std.fmt.parseInt(usize, second_int_slice, 10) catch {
                std.debug.print("Failed to parse second int from '{s}'\n", .{second_int_slice});
                return TokenParseError.InvalidFace;
            };
        }

        if (c == ' ') {
            return .{ .vtn = .{ first_int_res, second_int_res, null }, .rest = working_slice[i + 1 ..] };
        }

        working_slice = eat_ignored(working_slice[i + 1 ..]);
    }

    if (working_slice.len == 0) {
        return .{ .vtn = .{ first_int_res, second_int_res, null }, .rest = working_slice };
    }

    // If the next character is a slash or space, we are done. Otherwise, we have to parse
    // another integer.
    var third_int_res: ?usize = null;
    if (working_slice[0] == ' ' or working_slice[0] == '/') {
        return .{ .vtn = .{ first_int_res, second_int_res, null }, .rest = working_slice };
    } else {
        i = 0;
        while (i < working_slice.len) : (i += 1) {
            c = working_slice[i];

            if (c == '/' or c == ' ') {
                break;
            }
        }

        const third_int_slice = working_slice[0..i];
        third_int_res = std.fmt.parseInt(usize, third_int_slice, 10) catch {
            std.debug.print("Failed to parse third int from '{s}'\n", .{third_int_slice});
            return TokenParseError.InvalidFace;
        };

        working_slice = working_slice[i..];
    }

    return .{ .vtn = .{ first_int_res, second_int_res, third_int_res }, .rest = working_slice };
}

fn eat_face(input: []u8) (TokenParseError)!Face {
    var working_slice = eat_ignored(input);

    const first_res = parse_face_triple(working_slice) catch |err| {
        std.debug.print("Failed to parse first face triple\n", .{});
        return err;
    };
    working_slice = eat_ignored(first_res.rest);

    const second_res = parse_face_triple(working_slice) catch |err| {
        std.debug.print("Failed to parse second face triple\n", .{});
        return err;
    };
    working_slice = eat_ignored(second_res.rest);

    const third_res = parse_face_triple(working_slice) catch |err| {
        std.debug.print("Failed to parse third face triple. Working slice: '{s}'\n", .{working_slice});
        return err;
    };
    working_slice = eat_ignored(third_res.rest);

    if (working_slice.len != 0) {
        std.debug.print("Characters remaining after parsing face: '{s}'", .{working_slice});
        return TokenParseError.InvalidFace;
    }

    return Face{ first_res.vtn, second_res.vtn, third_res.vtn };
}

/// Main entrypoint.
pub fn parse(input: anytype, allocator: std.mem.Allocator) !LoadedObj {
    std.debug.print("Parsing OBJ file...\n", .{});

    var vertices = std.ArrayList(Vec3).init(allocator);
    var normals = std.ArrayList(Vec3).init(allocator);
    var texture_coords = std.ArrayList(Vec3).init(allocator);
    var faces = std.ArrayList(Face).init(allocator);

    // A line is unlikely to be more than 100 bytes.
    var line_buf = [_]u8{0} ** 512;
    var fba = std.heap.FixedBufferAllocator.init(&line_buf);
    var line_arraylist = std.ArrayList(u8).init(fba.allocator());
    var line_writer = line_arraylist.writer();

    while (true) {
        // Clear the contents (i.e. the previous line) of the array list.
        line_arraylist.items.len = 0;

        input.streamUntilDelimiter(line_writer, '\n', 512) catch |err| {
            switch (err) {
                error.EndOfStream => {
                    // We've reached the end of the file.
                    if (line_arraylist.items.len == 0) {
                        // The last line was empty.
                        break;
                    }
                },
                else => {
                    return err;
                },
            }
        };

        var line_slice = line_arraylist.items;
        std.debug.print("Line: '{s}'\n", .{line_slice});
        line_slice = eat_ignored(line_slice);
        if (line_slice.len == 0) {
            // This line is empty or a comment.
            continue;
        }

        const starting_token = eat_starting_token(line_slice) catch |err| {
            std.debug.print("error\n", .{});
            return err;
        };

        switch (starting_token.token) {
            .Vertex => {
                const vertex = try eat_vertex(starting_token.rest);
                try vertices.append(vertex);
            },
            .Normal => {
                const normal = try eat_normal(starting_token.rest);
                try normals.append(normal);
            },
            .TextureCoord => {
                const texture_coord = try eat_texture_coord(starting_token.rest);
                try texture_coords.append(texture_coord);
            },
            .Face => {
                const face = try eat_face(starting_token.rest);
                try faces.append(face);
            },
        }
    }

    return LoadedObj{
        .vertices = vertices,
        .normals = normals,
        .texture_coords = texture_coords,
        .faces = faces,
    };
}

test "bare bones" {
    std.debug.print("Running test...\n", .{});

    const raw_input =
        \\# vertex coordinates
        \\v 8 0 11.0
        \\v 16 0 6 
        \\v 3 0 3
        \\
        \\#vertex textures
        \\vt 0.500 -1.352 0.234 #vertex texture
        \\
        \\#vertex normal 
        \\vn -0.717798 -0.043116 0.694915
        \\vn -0.322618 -0.014997 0.946410
        \\vn -0.218708 -0.027535 0.975402
        \\
        \\# faces 
        \\f 0//0 1//0 2//2
        \\f 1/0/0 2/1/0 0//2
        \\f 2 1 0
    ;
    var stream = std.io.fixedBufferStream(raw_input);
    var reader = stream.reader();

    var out = parse(reader, std.testing.allocator) catch {
        std.debug.print("error\n", .{});
        return;
    };
    defer out.deinit();

    try std.testing.expect(out.vertices.items.len == 3);
    try std.testing.expect(out.normals.items.len == 3);
    try std.testing.expect(out.texture_coords.items.len == 1);
    try std.testing.expect(out.faces.items.len == 3);
}
