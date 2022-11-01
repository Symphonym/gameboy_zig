const SpriteAttribute = @This();

x_pos: u8,
y_pos: u8,
tile_index: u8,
flags: u8,

pub const Flags = enum(u8) {
    BG_Window_Over_Obj = 0x80, // (0=No, 1=BG and Window colors 1-3 over the OBJ)
    Y_Flip = 0x40, // (0=Normal, 1=Vertically mirrored)
    X_Flip = 0x20, // (0=Normal, 1=Horizontally mirrored)
    Palette_Number = 0x10, // **Non CGB Mode Only** (0=OBP0, 1=OBP1)
};

pub fn getFlag(self: SpriteAttribute, flag: Flags) bool {
    return self.flags & @enumToInt(flag) != 0;
}

