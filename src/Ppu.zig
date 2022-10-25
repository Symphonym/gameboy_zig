const std = @import("std");

const sf = @import("sfml.zig");
const MemoryBank = @import("MemoryBank.zig");
const tile_util = @import("tile_util.zig");
const TileCoordinate = tile_util.Coord;
const TileMap = @import("TileMap.zig");

const Ppu = @This();

tile_sheet: *sf.sfTexture,
first_tilemap: TileMap,
second_tilemap: TileMap,
memory_bank: *MemoryBank,

pub fn init(memory_bank: *MemoryBank) Ppu {
    return .{
        .first_tilemap = TileMap.init(),
        .second_tilemap = TileMap.init(),
        .tile_sheet = sf.sfTexture_create(
            @intCast(c_int, tile_util.tile_sheet_width * tile_util.tile_pixel_dimension),
            @intCast(c_int, tile_util.tile_sheet_height * tile_util.tile_pixel_dimension)) orelse unreachable,
        .memory_bank = memory_bank
    };
}

pub fn deinit(self: *Ppu) void {
    self.first_tilemap.deinit();
    self.second_tilemap.deinit();
}

pub fn tick(self: *Ppu) void {
    if (self.memory_bank.vram_changed) {
        self.regenerateTileSheet();
    }
}

pub fn getTileCoordinate(self: Ppu, tile_index: i16) TileCoordinate {
    // Check which tile addressing mode we're using
    if (self.memory_bank.lcd_control.getFlag(.BG_Window_TileDataArea)) {
        return tile_util.getTileCoordinateFromTileIndex(128 + tile_index);
    } else {
        return tile_util.getTileCoordinateFromTileIndex(tile_index);
    }
}

pub fn getTileCoordinateForSprite(tile_index: u8) TileCoordinate {
    return getTileCoordinateForSprite(tile_index);
}

pub fn draw(self: *Ppu, window: *sf.sfRenderWindow) void {
    self.first_tilemap.draw(window, self.tile_sheet);
}

// Parses a raw line of the tile in memory and returns data in RGBA32 format
fn parseTileLineToRGBA32(tile_line: *[2]u8) [32]u8 {
    var bit_index: usize = 0;
    // TODO: Use actual palette values
    const palette_offset = 30;

    var RGBA32_data: [32]u8 = .{0} ** 32;

    while (bit_index < 8) : (bit_index += 1) {
        const left_bit = (tile_line[0] >> @intCast(u3, 7 - bit_index)) & 0x1;
        const right_bit = (tile_line[1] >> @intCast(u3, 7 - bit_index)) & 0x1;

        const color_ID = left_bit + right_bit << 1;

        const RGBA32_offset: u8 = @intCast(u8, bit_index) * 4;
        RGBA32_data[RGBA32_offset] = color_ID * palette_offset; 
        RGBA32_data[RGBA32_offset + 1] = color_ID * palette_offset;
        RGBA32_data[RGBA32_offset + 2] = color_ID * palette_offset;
        RGBA32_data[RGBA32_offset + 3] = 255; // Ignore transparency for now
    }

    return RGBA32_data;
}

fn regenerateTileSheet(self: *Ppu) void {
    var address: usize = 0;
    const end_address = 0x97FF - 0x8000;

    const bytes_per_RGBA32_pixel = 4;
    const RGBA32_data_count = tile_util.tile_pixel_dimension * tile_util.tile_pixel_dimension * bytes_per_RGBA32_pixel;

    var tile_RGBA32_data: [RGBA32_data_count]u8 = .{0} ** RGBA32_data_count;


    while (address < end_address) : (address += tile_util.tile_byte_size) {
        const tile_sheet_coordinate = tile_util.getTileCoordinateFromTileIndex(@divFloor(address, 16));

        const tile_data = self.memory_bank.video_ram[address..][0..tile_util.tile_byte_size];

        var tile_row_index: usize = 0;
        while (tile_row_index < tile_util.tile_pixel_dimension) : (tile_row_index += 1) {
            const tile_line_data = tile_data[(tile_row_index * 2)..][0..2];

            std.mem.copy(u8,
                tile_RGBA32_data[(bytes_per_RGBA32_pixel * tile_row_index * tile_util.tile_pixel_dimension)..][0..(bytes_per_RGBA32_pixel * 8)],
                &parseTileLineToRGBA32(tile_line_data));
        }

        sf.sfTexture_updateFromPixels(
            self.tile_sheet,
            &tile_RGBA32_data[0],
            @intCast(c_uint, 8),
            @intCast(c_uint, 8),
            @intCast(c_uint, tile_sheet_coordinate.x * tile_util.tile_pixel_dimension),
            @intCast(c_uint, tile_sheet_coordinate.y * tile_util.tile_pixel_dimension));
    }

    var image = sf.sfTexture_copyToImage(self.tile_sheet);
    defer sf.sfImage_destroy(image);

    const tilemap_path = "./tilemap_dump.png";
    std.debug.print("Tilemap Dump ({s}) result: {}\n", .{tilemap_path, sf.sfImage_saveToFile(image, "./tilemap_dump.png")});
}