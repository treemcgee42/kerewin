pub usingnamespace @cImport({
    @cDefine("STBI_FAILURE_USERMSG", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});
