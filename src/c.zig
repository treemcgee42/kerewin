pub const raylib = struct {
    pub usingnamespace @cImport({
        @cInclude("raylib.h");
    });
};

pub const raygui = struct {
    pub usingnamespace @cImport({
        @cInclude("raygui.h");
    });
};
