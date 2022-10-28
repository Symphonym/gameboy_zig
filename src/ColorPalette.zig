const std = @import("std");
const testing = std.testing;

const ColorPalette = @This();

pub const Colors = enum(u2) {
    White = 0,
    LightGray = 1,
    DarkGray = 2,
    Black = 3
};

palette: u8 = 0,

pub fn getColorForID(self: *ColorPalette, ID: u3) Colors {
    return @intToEnum(Colors, (self.palette >> ID) & 0x3);
}

test "Color palettes" {
    
    var palette = ColorPalette {};
    palette.palette = 0b1101;

    try testing.expectEqual(Colors.Black, palette.getColorForID(1));
    try testing.expectEqual(Colors.LightGray, palette.getColorForID(0));
}