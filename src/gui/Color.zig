
const Color = @This();

r: f32 = 1.0,
g: f32 = 1.0,
b: f32 = 1.0,
a: f32 = 1.0,

pub fn initFloat(r: f32, g: f32, b: f32, a: f32) Color {
    return .{
        .r = r, .g = g, .b = b, .a = a
    };
}

pub fn initRGBA8(r: u8, g: u8, b: u8, a: u8) Color {
    return .{
        .r = @intToFloat(f32, r) / 255.0,
        .g = @intToFloat(f32, g) / 255.0,
        .b = @intToFloat(f32, b) / 255.0,
        .a = @intToFloat(f32, a) / 255.0
    };
}

pub fn toRGBA8Array(self: Color) [4]u8 {
    return [4]u8 { 
        @floatToInt(u8, self.r * 255.0), 
        @floatToInt(u8, self.g * 255.0), 
        @floatToInt(u8, self.b * 255.0), 
        @floatToInt(u8, self.a * 255.0)
    };
}

pub fn toRGBAFloatArray(self: Color) [4]u8 {
    return [4]u8 { self.r, self.g , self.b, self.a };
}