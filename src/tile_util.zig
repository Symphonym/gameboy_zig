
pub const tile_count = 384;
pub const tile_sheet_width = 20; // How many tiles we store per row in the tilesheet
pub const tile_sheet_height = @floatToInt(comptime_int, @ceil(@intToFloat(f32, tile_count) / @intToFloat(f32, tile_sheet_width)));
pub const tile_pixel_dimension = 8; // 8x8 tiles
pub const tile_byte_size = 16;

pub fn Point(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

pub const Coord = Point(usize);
pub const FloatCoord = Point(f32);

pub fn getTileCoordinateFromTileIndex(index: usize) Coord {
    const tile_sheet_x = index % tile_sheet_width;
    const tile_sheet_y = @divFloor(index, tile_sheet_width);

    return .{
        .x = tile_sheet_x,
        .y = tile_sheet_y
    };
}
