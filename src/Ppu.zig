const std = @import("std");

const sf = @import("sfml.zig");
const MemoryBank = @import("MemoryBank.zig");

const Ppu = @This();

tile_sheet: ?*sf.sfTexture,
memory_bank: *MemoryBank,

const tile_count = 384;
const tile_sheet_width = 20; // How many tiles we store per row in the tilesheet
const tile_sheet_height = @floatToInt(comptime_int, @ceil(@intToFloat(f32, tile_count) / @intToFloat(f32, tile_sheet_width)));
const tile_dimension = 8; // 8x8 tiles
const tile_byte_size = 16;

pub fn init(memory_bank: *MemoryBank) Ppu {
    return .{
        .tile_sheet = sf.sfTexture_create(
            @intCast(c_int, tile_sheet_width * tile_dimension),
            @intCast(c_int, tile_sheet_height * tile_dimension)),
        .memory_bank = memory_bank
    };
}

pub fn tick(self: *Ppu) void {
    if (self.memory_bank.vram_changed) {
        self.regenerateTileSheet();

    }
}

pub fn draw(self: *Ppu, window: ?*sf.sfRenderWindow) void {
    var sprite = sf.sfSprite_create();
    defer sf.sfSprite_destroy(sprite);
    sf.sfSprite_setTexture(sprite, self.tile_sheet, @intCast(c_uint, 1));

    // var renderState = sf.sfRenderStates {
    //     .blendMode = sf.sfBlendMultiply,
    // };
    sf.sfRenderWindow_drawSprite(window, sprite, 0);
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

    var tile_index: usize = 0;
    var tile_sheet_y: usize = 0;

    const bytes_per_RGBA32_pixel = 4;
    const RGBA32_data_count = tile_dimension * tile_dimension * bytes_per_RGBA32_pixel;

    var tile_RGBA32_data: [RGBA32_data_count]u8 = .{0} ** RGBA32_data_count;


    while (address < end_address) : (address += tile_byte_size) {
        const tile_sheet_x = tile_index % tile_sheet_width;
        tile_sheet_y += if (tile_index > 0 and tile_index % tile_sheet_width == 0) 1 else 0;
        tile_index += 1;

        const tile_data = self.memory_bank.video_ram[address..][0..tile_byte_size];

        var tile_row_index: usize = 0;
        while (tile_row_index < tile_dimension) : (tile_row_index += 1) {
            const tile_line_data = tile_data[(tile_row_index * 2)..][0..2];

            std.mem.copy(u8,
                tile_RGBA32_data[(bytes_per_RGBA32_pixel * tile_row_index * tile_dimension)..][0..(bytes_per_RGBA32_pixel * 8)],
                &parseTileLineToRGBA32(tile_line_data));
        }

        sf.sfTexture_updateFromPixels(
            self.tile_sheet,
            &tile_RGBA32_data[0],
            @intCast(c_uint, 8),
            @intCast(c_uint, 8),
            @intCast(c_uint, tile_sheet_x * tile_dimension),
            @intCast(c_uint, tile_sheet_y * tile_dimension));
    }

    var image = sf.sfTexture_copyToImage(self.tile_sheet);
    defer sf.sfImage_destroy(image);
    std.debug.print("SAVE RESULT {}", .{sf.sfImage_saveToFile(image, "hello.png")});
}