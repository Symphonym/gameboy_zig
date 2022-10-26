const std = @import("std");
const testing = std.testing;

const PixelFIFO = @This();

const Pixel = struct {
    color_ID: u2,
    palette: u3,
    background_priority: bool
};

const Fifo = std.fifo.LinearFifo(Pixel, .{ .Static = 16});

fifo: Fifo = Fifo.init(),

pub fn push(self: *PixelFIFO, pixel: Pixel) !void {
    try self.fifo.writeItem(pixel);
}

pub fn pop(self: *PixelFIFO) Pixel {
    return self.fifo.readItem() orelse unreachable;
}

test "Pixel FIFO push & pop" {
    var fifo = PixelFIFO {};

    const pixel_a = Pixel { .color_ID = 0, .palette = 0, .background_priority = false };
    const pixel_b = Pixel { .color_ID = 1, .palette = 0, .background_priority = false };

    try fifo.push(pixel_a);
    try fifo.push(pixel_b);
    try fifo.push(pixel_b);
    try fifo.push(pixel_b);

    try testing.expectEqual(@intCast(u2, 0), fifo.pop().color_ID);
    try testing.expectEqual(@intCast(u2, 1), fifo.pop().color_ID);
    try testing.expectEqual(@intCast(u2, 1), fifo.pop().color_ID);
    try testing.expectEqual(@intCast(u2, 1), fifo.pop().color_ID);
}