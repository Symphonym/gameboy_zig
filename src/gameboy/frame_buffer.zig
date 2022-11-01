const Color = @import("../gui/Color.zig");


pub fn FrameBuffer(comptime width: u32, comptime height: u32) type {
    return struct {
        const Self = @This();

        buffer: [width * height * 4]u8,

        pub fn init() Self {
            return .{
                .buffer = .{0} ** (width * height * 4)
            };
        }

        pub fn getWidth(self: Self) u32 {
            _ = self;
            return width;
        }

        pub fn getHeight(self: Self) u32 {
            _ = self;
            return height;
        }

        pub fn getBufferSize(self: Self) u32 {
            return self.buffer.len;
        }

        pub fn setPixel(self: *Self, x: u32, y: u32, color: Color) void {
            const offset: u32 = (y * width + x) * 4;
            const rgba8_color = color.toRGBA8Array();
            self.buffer[offset] = rgba8_color[0];
            self.buffer[offset + 1] = rgba8_color[1];
            self.buffer[offset + 2] = rgba8_color[2];
            self.buffer[offset + 3] = rgba8_color[3];
        }
    };
}